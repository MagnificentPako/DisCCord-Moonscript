-- File: fix.moon
local *

----------------------------------
-- Function: require
-- A small helper function for easier import statements.
--
-- Parameters:
--   file - the file you want to require (with or without .lua extension)
--
-- Returns:
--  Whatever the file returns.
----------------------------------
require = (file) ->
    if fs.exists file
      dofile file
    else
      dofile file..".lua"

{:require}
