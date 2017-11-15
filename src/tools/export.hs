-- Copyright (C) 2017 Red Hat, Inc.
--
-- This library is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
--
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library; if not, see <http://www.gnu.org/licenses/>.

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

import           Control.Conditional(cond, ifM)
import           Control.Monad(unless, when)
import           Control.Monad.Except(MonadError, runExceptT)
import           Control.Monad.IO.Class(MonadIO, liftIO)
import           Data.Conduit(Consumer, (.|), runConduit)
import qualified Data.Conduit.List as CL
import           Data.ContentStore(openContentStore, runCsMonad)
import           Data.List(isSuffixOf, isPrefixOf, partition)
import qualified Data.Text as T
import           System.Directory(doesFileExist, removePathForcibly)
import           System.Environment(getArgs)
import           System.Exit(exitFailure)

import qualified BDCS.CS as CS
import           BDCS.DB(Files, checkAndRunSqlite)
import           BDCS.Files(groupIdToFilesC)
import           BDCS.Groups(getGroupIdC)
import           BDCS.Version
import qualified Export.Directory as Directory
import qualified Export.Qcow2 as Qcow2
import qualified Export.Ostree as Ostree
import qualified Export.Tar as Tar
import           Export.Utils(runHacks, runTmpfiles)
import           Utils.Either(whenLeft)
import           Utils.Monad(concatMapM)

-- | Check a list of strings to see if any of them are files
-- If it is, read it and insert its contents in its place
expandFileThings :: [String] -> IO [String]
expandFileThings = concatMapM isThingFile
  where
    isThingFile :: String ->  IO [String]
    isThingFile thing = ifM (doesFileExist thing)
                            (lines <$> readFile thing)
                            (return [thing])

usage :: IO ()
usage = do
    printVersion "export"
    putStrLn "Usage: export metadata.db repo dest thing [thing ...]"
    putStrLn "dest can be:"
    putStrLn "\t* A directory (which may or may not already exist)"
    putStrLn "\t* The name of a .tar file to be created"
    putStrLn "\t* The name of a .qcow2 image to be created"
    putStrLn "\t* A directory ending in .repo, which will create a new ostree repo"
    putStrLn "thing can be:"
    putStrLn "\t* The NEVRA of an RPM, e.g. filesystem-3.2-21.el7.x86_64"
    putStrLn "\t* A path to a file containing NEVRA of RPMs, 1 per line."
    -- TODO group id?
    exitFailure

needFilesystem :: IO ()
needFilesystem = do
    printVersion "export"
    putStrLn "ERROR: The tar needs to have the filesystem package included"
    exitFailure

needKernel :: IO ()
needKernel = do
    printVersion "export"
    putStrLn "ERROR: ostree exports need a kernel package included"
    exitFailure

{-# ANN main ("HLint: ignore Use head" :: String) #-}
main :: IO ()
main = do
    argv <- getArgs

    when (length argv < 4) usage

    let db_path = T.pack (argv !! 0)
    let out_path = argv !! 2
    allThings <- expandFileThings $ drop 3 argv

    repo <- runCsMonad (openContentStore (argv !! 1)) >>= \case
        Left e  -> print e >> exitFailure
        Right r -> return r

    let (match, otherThings) = partition (isPrefixOf "filesystem-") allThings
    when (length match < 1) needFilesystem
    let things = map T.pack $ match !! 0 : otherThings

    when (".repo" `isSuffixOf` out_path) $
        unless (any ("kernel-" `T.isPrefixOf`) things) needKernel

    let (handler, objectSink) = cond [(".tar" `isSuffixOf` out_path,   (cleanupHandler out_path, CS.objectToTarEntry .| Tar.tarSink out_path)),
                                      (".qcow2" `isSuffixOf` out_path, (cleanupHandler out_path, Qcow2.qcow2Sink out_path)),
                                      (".repo" `isSuffixOf` out_path,  (cleanupHandler out_path, Ostree.ostreeSink out_path)),
                                      (otherwise,                      (print, directoryOutput out_path))]

    result <- runExceptT $ checkAndRunSqlite db_path $ runConduit $ CL.sourceList things
        .| getGroupIdC
        .| groupIdToFilesC
        .| CS.filesToObjectsC repo
        .| objectSink

    whenLeft result (\e -> handler e >> exitFailure)
 where
    directoryOutput :: (MonadError String m, MonadIO m) => FilePath -> Consumer (Files, CS.Object) m ()
    directoryOutput path = do
        -- Apply tmpfiles.d to the directory first
        liftIO $ runTmpfiles path

        Directory.directorySink path
        liftIO $ runHacks path

    cleanupHandler :: Show a => FilePath -> a -> IO ()
    cleanupHandler path e = print e >> removePathForcibly path