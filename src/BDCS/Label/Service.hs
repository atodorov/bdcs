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

module BDCS.Label.Service(matches,
                          mkLabel)
 where

import qualified Data.Text as T
import           System.FilePath.Posix(takeExtension)

import BDCS.DB(Files(..))
import BDCS.Label.Types(Label(..))

matches :: Files -> Bool
matches Files{..} =
    takeExtension (T.unpack filesPath) == ".service"

mkLabel :: Files -> Maybe Label
mkLabel _ = Just ServiceLabel
