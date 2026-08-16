import type { Metadata } from "next";
import "./globals.css";
import ClientProviders from "./ClientProviders";

export const metadata: Metadata = {
  title: "SafeFleet Command Center",
  description:
    "Trung tâm điều hành đội xe thông minh — SafeFleet Agentic AI",
  keywords: ["fleet management", "vehicle tracking", "driver safety", "AI"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="vi" className="h-full" suppressHydrationWarning>
      <head>
        <meta name="theme-color" content="#eef2f4" />
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var m=localStorage.getItem('safefleet-theme')||'system';var d=m==='dark'||(m==='system'&&matchMedia('(prefers-color-scheme: dark)').matches);var r=document.documentElement;r.classList.toggle('dark',d);r.dataset.theme=d?'dark':'light';r.style.colorScheme=d?'dark':'light';var t=document.querySelector('meta[name="theme-color"]');if(t)t.setAttribute('content',d?'#060e14':'#eef2f4')}catch(e){}})();`,
          }}
        />
      </head>
      <body className="min-h-full flex flex-col antialiased">
        <ClientProviders>{children}</ClientProviders>
      </body>
    </html>
  );
}
