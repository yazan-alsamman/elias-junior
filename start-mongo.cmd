@echo off
setlocal EnableExtensions
cd /d "%~dp0"

rem Use 8.3 short path so db/log paths have no spaces — MongoDB fails opening files under "New folder" otherwise.
for %%I in (.) do set "SHORT=%%~sI"
if not exist "%SHORT%\mongo-data" mkdir "%SHORT%\mongo-data"

"C:\Program Files\MongoDB\Server\8.2\bin\mongod.exe" ^
  --dbpath "%SHORT%\mongo-data" ^
  --logpath "%SHORT%\mongo-data\mongod.log" ^
  --port 27018 ^
  --bind_ip 127.0.0.1
