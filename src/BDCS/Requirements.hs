-- Copyright (C) 2016-2017 Red Hat, Inc.
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

module BDCS.Requirements(insertRequirement,
                         insertGroupRequirement)
 where

import Control.Monad.IO.Class(MonadIO)
import Database.Esqueleto

import BDCS.DB(GroupRequirements(..), Requirements(..), orInsert)
import BDCS.Groups(findRequires, findGroupRequirements)

insertGroupRequirement :: MonadIO m => GroupRequirements -> SqlPersistT m (Key GroupRequirements)
insertGroupRequirement gr@GroupRequirements{..} =
    findGroupRequirements groupRequirementsGroup_id groupRequirementsReq_id `orInsert` gr

insertRequirement :: MonadIO m => Requirements -> SqlPersistT m (Key Requirements)
insertRequirement req@Requirements{..} =
    findRequires requirementsReq_language requirementsReq_context requirementsReq_strength requirementsReq_expr `orInsert` req
