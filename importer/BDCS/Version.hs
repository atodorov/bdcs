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
{-# LANGUAGE TemplateHaskell #-}

module BDCS.Version(printVersion)
  where

import Data.Version (showVersion)
import Development.GitRev
import Text.Printf(printf)

import Paths_db (version)


printVersion :: String -> IO ()
printVersion toolName = do
    let git_version = $(gitDescribe)
    if git_version == "UNKNOWN" then
        printf "%s v%s\n" toolName $ showVersion version
    else
        printf "%s %s\n" toolName git_version