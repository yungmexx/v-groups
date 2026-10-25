fx_version 'cerulean'
game 'gta5'

description 'V-Groups'
version '1.0.2'

lua54 'yes'

shared_script {
    'config/*.lua',
}

client_scripts {
    'client/*.lua',
}

server_script {
    'server/*.lua',
}


files {
    'html/index.html',
    'html/script.js',
    'html/style.css',
	'html/assets/**',
}

ui_page 'html/index.html'
