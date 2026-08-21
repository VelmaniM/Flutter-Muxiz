const errorHandler = (err, req, res, next) => {
  console.error(`🚨 [API Error] ${req.method} ${req.originalUrl}:`, err.message);

  if (err.type === 'entity.too.large' || err.status === 413) {
    return res.status(413).json({
      success: false,
      message: 'File or payload too large. Please use Direct Google Drive Upload.',
    });
  }

  const statusCode = res.statusCode === 200 ? 500 : res.statusCode;
  res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal Server Error',
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  });
};

module.exports = errorHandler;
