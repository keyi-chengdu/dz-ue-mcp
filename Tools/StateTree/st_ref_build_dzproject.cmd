@echo off
call "C:\UE\Engines\UE_5.8\Engine\Build\BatchFiles\Build.bat" DZProjectEditor Win64 Development -project="C:\UE\Projects\DZ_Project_New\DZ_Content\DZProject.uproject" -WaitMutex > "C:\UE\Projects\DZ_Project_New\.dsh\st_work\build_dzproject.log" 2>&1
exit /b %ERRORLEVEL%
