import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Fully static site, deployed to Firebase Hosting (booqora-infidec.web.app).
  output: "export",
  trailingSlash: false,
  images: { unoptimized: true },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
