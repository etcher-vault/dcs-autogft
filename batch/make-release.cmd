@echo off

set /p version=<version.txt

set example_mission="C:\Users\birge\Saved Games\DCS\Missions\autogft-example.miz"
set build_dir=build
set archive_dir=build-zip
set archive_file=%archive_dir%\autogft-%version%.zip

set current_dir=%cd%
cd ..
call make.cmd
call make-docs.cmd

copy README.md %build_dir%\README.txt

copy %example_mission% %build_dir%\example-%version%.miz

md %build_dir%\docs
copy docs %build_dir%\docs

if exist %archive_dir% (
	if exist %archive_file% del %archive_file%
) else md %archive_dir%
cd %build_dir%
7z a ..\%archive_file% *.* docs\
cd %current_dir%