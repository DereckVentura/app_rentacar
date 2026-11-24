import type { Metadata } from "next";
import "./globals.css";
import "./autorent.css";
import "./interface.css";

export const metadata: Metadata = {
  title: "AutoRent · Rent a Car Molina",
  appleWebApp: { capable: true, title: "AutoRent", statusBarStyle: "black-translucent" },
  manifest: "/manifest.webmanifest",
  description: "Consulta la flota y reserva tu próximo viaje en La Unión y San Miguel.",
  icons: {
    icon: "/brand/logo.png",
    apple: "/brand/logo.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es-SV">
      <head>
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-title" content="AutoRent" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
      </head>
      <body className="antialiased">{children}</body>
    </html>
  );
}
