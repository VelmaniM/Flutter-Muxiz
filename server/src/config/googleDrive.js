const { google } = require('googleapis');

const getOAuth2Client = () => {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const redirectUri = process.env.GOOGLE_REDIRECT_URI || 'https://developers.google.com/oauthplayground';
  const refreshToken = process.env.GOOGLE_DRIVE_REFRESH_TOKEN;
  const accessToken = process.env.GOOGLE_DRIVE_ACCESS_TOKEN;

  const auth = new google.auth.OAuth2(clientId, clientSecret, redirectUri);
  auth.setCredentials({
    access_token: accessToken,
    refresh_token: refreshToken,
  });
  return auth;
};

const getAccessToken = async () => {
  if (process.env.GOOGLE_DRIVE_ACCESS_TOKEN) {
    return process.env.GOOGLE_DRIVE_ACCESS_TOKEN;
  }
  const auth = getOAuth2Client();
  const res = await auth.getAccessToken();
  return res.token;
};

const getDriveClient = () => {
  const auth = getOAuth2Client();
  return google.drive({ version: 'v3', auth });
};

module.exports = {
  getOAuth2Client,
  getAccessToken,
  getDriveClient,
  FOLDER_ID: process.env.GOOGLE_DRIVE_FOLDER_ID || '1bbMqTYNNmLTuhQOWmFw9HxiIbiCXKQwi',
};
