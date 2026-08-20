import './globals.css';

export const metadata = {
  title: 'Muxiz Studio — Cloud Ingestion & Database Catalog',
  description: 'Next.js React Music Management, Bulk Ingestion & Streaming Engine for Muxiz.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/app_logo.png" />
      </head>
      <body>{children}</body>
    </html>
  );
}
