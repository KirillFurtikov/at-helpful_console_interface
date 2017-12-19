@echo OFF
:START
set VERSION=0.7.2
:: Сохранить файл с нужной кодировкой и если текст корректно не отображается, то попробовать разные числовые значения
:: Кодировки:
:: 65001	-	для UTF-8
:: 866		-	OEM-866 MS-DOS-кодировка
:: 1251		-	кириллица (с ANSI)
chcp 65001 

:: ----- ДЕФОЛТНЫЕ НАСТРОЙКИ:
:: - Путь, куда копировать отчеты аллюра (без слеша в конце!)
set ALLURE_TARGET_DIR=C:\allure\allure_reports
:: Порт по умолчанию для запуска сервера
set PORT=62000
:: - Директория allure
set ALLURE_DIR=%cd%\allure
set UPDATE_HOST=http://10.101.100.105
title Генератор отчетов Allure v%VERSION%
CLS

echo ##############################
:: Выводим текушую директорию
echo # Текущая директория: %cd%
echo ##############################
echo # Выбери действие:
echo # 1) Генерировать отчет
echo # 2) Запустить сервер
echo # 3) Проверить обновления скрипта
echo # 4) Выйти
echo ##############################
choice /C 1234 >NUL
if errorlevel == 1 set ACTION=:CHECKALLUREDIR
if errorlevel == 2 set ACTION=:RUNSERVER %ALLURE_TARGET_DIR%, %PORT%
if errorlevel == 3 set ACTION=:CHECKUPDATES
if errorlevel == 4 set ACTION=:QUIT
call %ACTION%
exit /B 0

:CHECKUPDATES
if exist %cd%\LAST_VERSION del %cd%\LAST_VERSION
start /WAIT /MIN "Проверка обновлений" CMD /C call bitsadmin /transfer "CheckUpdates" %UPDATE_HOST%/ATREPORT_LAST_VERSION %cd%\LAST_VERSION
set /P NEW_VERSION=<LAST_VERSION
if not "%VERSION%"=="%NEW_VERSION%" (
	echo # Есть обновления скрипта [с %VERSION% до %NEW_VERSION%]
	for /F "delims=*" %%A in ('findstr /I URL LAST_VERSION') do echo # %%A
) else (
	echo # Обновлений не найдено 
)
echo ##############################
exit /B 0

:FILLENVIRONMENT
:: Ниже описана структура файла для добавления информации в раздел Environment при генерировании отчета
for /F "delims=*" %%A in ('FINDSTR /I browser: lib\configs\main_config.yml') do set browserline=%%A

echo Browser = %browserline:~10,-1% > %ALLURE_DIR%\environment.properties
::if "%browserline:~10,-1%"=="chrome" (
	for /F "tokens=2" %%A in ('chromedriver -v') do set chromedriver_version=%%A
	echo ChromeDriver = %chromedriver_version% >> %ALLURE_DIR%\environment.properties
::)

for /F "tokens=3" %%A in ('reg query "HKEY_CURRENT_USER\Software\Google\Chrome\BLBeacon" /v version') do set chrome_version=%%A
echo Chrome = %chrome_version% >> %ALLURE_DIR%\environment.properties

echo Branch = %1 >> %ALLURE_DIR%\environment.properties
echo Project = %project% >> %ALLURE_DIR%\environment.properties
echo Generated_at = %TIME:~0,8% %DATE% >> %ALLURE_DIR%\environment.properties

for /F "delims=*" %%A in ('FINDSTR /I stand lib\configs\run.yml') do set stand=%%A
for /F "delims=*" %%A in ('FINDSTR /I knife_subdomain lib\configs\run.yml') do set subdomain=%%A
if "%stand%"=="stand: knife" (
	echo Stand = http://%subdomain:~17%.knife.railsc.ru/ >> %ALLURE_DIR%\environment.properties
)
exit /B 0

:CHECKALLUREDIR
:: Проверяем, что директория с отчетами есть
if not exist %ALLURE_DIR% goto NOREPORTS
echo # Директория с отчетами allure: %ALLURE_DIR%
call :COPYREPORTS
exit /B 0

:COPYREPORTS
echo ##############################
echo # Выбери название проекта:
echo # 1) Пульс Цен
echo # 2) Близко
echo # 3) ЯПокупаю
echo ##############################
choice /C 123 >NUL
if errorlevel == 1 set project=Pulscen
if errorlevel == 2 set project=Blizko
if errorlevel == 3 set project=Yapokupayu
set /P branch=# Укажи ссылку на ревизию (или название ветки):  
call :FILLENVIRONMENT %branch%

set RESULT_DIR=%ALLURE_TARGET_DIR%\%project%\%date:~-2%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%\
echo # Отчет будет лежать тут %RESULT_DIR%
choice /M "# Генерируем?" /C yn
if errorlevel == 1 set ACTION=:SUCCESSFUL
if errorlevel == 2 set ACTION=:CANCEL
call %ACTION%
exit /B 0

:SETABSDIR
set /P ALLURE_DIR=# Укажите абсолютный путь к папке с отчетами: 
call :CHECKALLUREDIR
exit /B 0

:NOREPORTS
echo # Директория с отчетами allure не найдена! 
call :SETABSDIR
exit /B 0

:CANCEL
goto START
exit /B 0

:QUIT
exit /B 0

:SUCCESSFUL
echo # Генерируем отчет на основе результатов из %ALLURE_DIR% в %RESULT_DIR%
start /WAIT /MIN "Генерация отчета Allure" cmd /C call allure generate %ALLURE_DIR% -o %RESULT_DIR%
echo # Отчет сгенерирован в %RESULT_DIR%
echo ##############################
choice /M "# Открыть отчет?" /C yn 
if errorlevel == 2 set ACTION=quit
if %ACTION%==quit goto START
call :RUNSERVER
exit /B 0

:RUNSERVER 
if "%1"=="" ( set "REPORTS_DIR=%RESULT_DIR%" ) ELSE ( set "REPORTS_DIR=%1" )
if "%2"=="" ( set /P "PORT=# Укажи порт [По умолчанию: %PORT%]: " ) ELSE ( set "PORT=%2" )
cmd /C call allure open %REPORTS_DIR% -p %PORT%
if errorlevel == 1 GOTO :RERUNSERVER %ALLURE_TARGET_DIR%
exit /B 0

:RERUNSERVER <ALLURE_TARGET_DIR>
echo ##############################
echo # Порт %PORT% занят.
echo ##############################
CALL :RUNSERVER %1
exit /B 0
