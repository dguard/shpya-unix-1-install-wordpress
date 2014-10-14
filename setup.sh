#!/usr/bin/env bash

# GLOBAL VARIABLES
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CURRENT_COMMAND=$1

# allowed commands
COMMANDS="install"
WORDPRESS_DOWNLOAD_URL="https://ru.wordpress.org/wordpress-4.0-ru_RU.zip"
ROOT_PASS=""

# run only allowed commands
if [ ${CURRENT_COMMAND} == ""  ] || [[ ${COMMANDS} != *${CURRENT_COMMAND}* ]]
then
     echo -en "Доступны следующие команды: "
     for COMMAND in ${COMMANDS}
        do
        echo -en ${COMMAND}" "
        done
     echo
     exit
fi

# install tasksel what can install multiple packages by one command
function install_tasksel {
   if [ "$(which tasksel)" == "" ]
   then
        echo "Устанавливается tasksel"
        sudo apt-get install tasksel
   else
        echo "tasksel уже установлен"
   fi
}

# install apache2, php5 and mysql
function install_lamp {
    if [ $(which apache2) == "" ] || [ $(which php5) == "" ] || [ $(which mysql) == "" ]
    then
        echo "Устанавливается lamp-server"
        install_tasksel
        sudo tasksel install lamp-server
    else
        echo "LAMP сервер установлен"
    fi
}

# run specified command in mysql as root
function mysql_run_command () {
    mysql -u root -p${ROOT_PASS} -e "$1"
}

# replace string in file by regexp or string
function replace_in_file () {
    sudo sed -ie "s|${1}|${2}|g" $3
}

function install {
    echo "Введите директорию для установки сайта и нажмите [ENTER]:"
    read WEBSITE_DIR

    echo "Введите адрес сайта (например, blog.ru) и нажмите [ENTER]:"
    read WEBSITE_NAME

    echo "Введите пароль для пользователя root в mysql и нажмите [ENTER]:"
    read ROOT_PASS

    echo "Введите имя новой базы данных mysql БЕЗ ТОЧЕК И СПЕЦСИМВОЛОВ и нажмите [ENTER]:"
    read DB_NAME

    echo "Введите имя нового пользователя mysql и нажмите [ENTER]:"
    read DB_USER

    echo "Введите пароль для нового пользователя mysql и нажмите [ENTER]:"
    read DB_PASS

    install_lamp

    # create db and user
    mysql_run_command "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
    mysql_run_command "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${DB_USER}@'localhost' IDENTIFIED BY '${DB_PASS}';"

    # prepare wordpress
    cd $(dirname ${WEBSITE_DIR})
    sudo wget ${WORDPRESS_DOWNLOAD_URL}
    sudo unzip $(basename ${WORDPRESS_DOWNLOAD_URL})
    sudo rm -rf $(basename ${WORDPRESS_DOWNLOAD_URL})*
    sudo mv wordpress ${WEBSITE_DIR}

    # change wp config file
    WP_CONFIG_FILE=${WEBSITE_DIR}/wp-config.php

    sudo mv ${WEBSITE_DIR}/wp-config-sample.php ${WP_CONFIG_FILE}
    replace_in_file "define('DB_NAME'.*" "define('DB_NAME', '${DB_NAME}');" ${WP_CONFIG_FILE}
    replace_in_file "define('DB_USER'.*" "define('DB_USER', '${DB_USER}');" ${WP_CONFIG_FILE}
    replace_in_file "define('DB_PASSWORD'.*" "define('DB_PASSWORD', '${DB_PASS}');" ${WP_CONFIG_FILE}

    # create new site for apache2
    APACHE_SITE=/etc/apache2/sites-available/${WEBSITE_NAME}.conf

    sudo cat ${SCRIPT_DIR}/apache2.example.conf | sudo tee ${APACHE_SITE}
    replace_in_file "{{DOCUMENT_ROOT}}" ${WEBSITE_DIR} ${APACHE_SITE}
    replace_in_file "{{SERVER_NAME}}" ${WEBSITE_NAME} ${APACHE_SITE}

    sudo a2ensite ${WEBSITE_NAME}.conf
    sudo a2enmod rewrite
    sudo service apache2 restart

    # update hosts
    replace_in_file "127.0.0.1\s\+" "127.0.0.1 ${WEBSITE_NAME} " /etc/hosts

    echo Go to http://${WEBSITE_NAME}/ to continue integration of your website!
}
install