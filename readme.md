# Dropbox MySQL Backup Script

This Bash script performs a secure backup of a MySQL database and uploads it to Dropbox using the Dropbox API. It loads configuration variables from a `.env` file and database credentials from a `.my.conf` file. The script supports Dropbox refresh tokens and performs automatic compression and cleanup after backup.

Requirements: Ensure the following tools are installed: `mysqldump`, `jq`, `curl`, `zip`. On Debian-based systems you can install them using:
```bash
sudo apt install mysql-client jq curl zip
```

MySQL credentials: Create a `.my.conf` file in the same directory as the script to securely store your MySQL user and password credentials. Example: 
```bash
cp dropbox.my.conf .my.conf && \
chmod 600 .my.conf
```
## Dropbox setup: 
1. Visit https://www.dropbox.com/developers/apps and log in.
2. Create a new app by selecting Scoped Access, Full Dropbox (or App Folder if you prefer limited access), and give it a name.
3. In the app settings, enable the following permission scopes: 
```
files.content.write | files.content.read.
```
4. Set the Redirect URI to: http://localhost
5. Save your App Key and App Secret in the .env file.

## To get a Dropbox refresh token:
**We use the refresh token because the access token generated from console expires after 4 hours**
1. Authorize the app by replacing {$APP_KEY} in the following URL and opening it in your browser:
```
https://www.dropbox.com/oauth2/authorize?client_id={$APP_KEY}&response_type=code&token_access_type=offline&redirect_uri=http://localhost
```
2. After authorizing, you'll be redirected to a URL like: (it can fail the redirect but you need the code embeded in the url) 
```
http://localhost/?code=YOUR_AUTHORIZATION_CODE
```
Copy the code from the URL.

3. Exchange the code for a refresh token by replacing placeholders in this curl command and running it:
```bash
curl -X POST https://api.dropboxapi.com/oauth2/token \
  -u {$APP_KEY}:{$APP_SECRET} \
  -d code={$AUTHORIZATION_CODE} \
  -d grant_type=authorization_code \
  -d redirect_uri=http://localhost
```
Copy the refresh_token from the JSON response.

## Prepare the env files and run the script
Prepare the environment file:
```bash
cp dropbox.env .env && \
chmod 600 .env
```
Edit the .env file and set:
```
APP_KEY=your_app_key
APP_SECRET=your_app_secret
REFRESH_TOKEN=your_refresh_token
DB_NAME=your_database_name
```

The script is ready to be executed and it will:
- Load environment variables from .env
- Dump the database using mysqldump
- Compress the SQL file into a zip archive
- Upload the archive to your Dropbox /backups/ folder
- Clean up the temporary files

Security tips:
- Do not commit .env or .my.conf to version control
- Run chmod 600 .env .my.conf to ensure only your user can read them

To automate backups, you can add the script to your crontab. Example to run every midnight:
```
0 0 * * * /path/to/mysql_backup.sh >> /var/log/mysql_dropbox_backup.log 2>&1
```