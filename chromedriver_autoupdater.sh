# Закинуть файл в папку, где должен лежать chromedriver
# Запускать, когда нужно обновить драйвер
export	DOMAIN='https://chromedriver.storage.googleapis.com/'
export	SYSTEM='windows64' # windows, windows32, windows64, linux32, linux64 or mac, mac32, mac64

case $SYSTEM in
     windows|windows32|windows64 )      
          export FILE_NAME='/chromedriver_win32.zip' ;;
     linux|linux32 )      
          export FILE_NAME='/chromedriver_linux32.zip' ;;
     linux64 )
          export FILE_NAME='/chromedriver_linux64.zip' ;; 
     mac|mac32|mac64 )
          export FILE_NAME='/chromedriver_mac64.zip' ;;
     *)
          read -p 'Что за бред ты написал в SYSTEM? Исправляй иди! Все, что будет работать указано в комментарии к строке!'
		  exit 1 ;;
esac

$(curl https://chromedriver.storage.googleapis.com/LATEST_RELEASE -o CHROME_LATEST_RELEASE)
if [ ! -f CURRENT_VERSION ] || [ ! `cat CHROME_LATEST_RELEASE` == `cat CURRENT_VERSION` ] || [ ! -f chromedriver.exe ]; then
	$(cp CHROME_LATEST_RELEASE CURRENT_VERSION)
export CHROME_LATEST_RELEASE=`head -n 1 CHROME_LATEST_RELEASE | tr -d "\n"`
	$(curl "$DOMAIN$CHROME_LATEST_RELEASE$FILE_NAME" -o "$CHROME_LATEST_RELEASE.zip")
	$(unzip "$CHROME_LATEST_RELEASE.zip" -d "chrome_$CHROME_LATEST_RELEASE")
	$(rm "$CHROME_LATEST_RELEASE.zip")
	$(mv "chrome_$CHROME_LATEST_RELEASE"/chromedriver.exe chromedriver.exe) && $(rm -r "chrome_$CHROME_LATEST_RELEASE")
	echo '---------------------------------------'
	echo "- Новая версия ($CHROME_LATEST_RELEASE) chromedriver установлена"
	echo '---------------------------------------'
else	
	echo '---------------------------------------'
	echo '- У тебя последняя версия chromedriver'
	echo '---------------------------------------'
fi
read -p 'Нажми enter, чтобы выйти...'
