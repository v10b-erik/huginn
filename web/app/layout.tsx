import type { ReactNode } from "react";

export const metadata = {
  title: "huginn",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="no">
      <body>{children}</body>
    </html>
  );
}
