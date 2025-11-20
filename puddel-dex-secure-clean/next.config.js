/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  assetPrefix: '',

  // Security headers for production deployment
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY'
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff'
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin'
          },
          {
            key: 'Permissions-Policy',
            value: 'camera=(), microphone=(), geolocation=()'
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block'
          }
        ]
      }
    ]
  },

  // Disable telemetry for privacy
  telemetry: false,

  // Disable X-Powered-By header
  poweredByHeader: false,

  webpack: (config, { dev, isServer }) => {
    // Webpack fallbacks
    config.resolve.fallback = {
      fs: false,
      net: false,
      tls: false,
    }

    // Build-time security validation
    if (!dev && isServer) {
      const network = process.env.NEXT_PUBLIC_NETWORK

      // Validate deployment network is set
      if (!network || !['testnet', 'mainnet'].includes(network)) {
        console.error('❌ NEXT_PUBLIC_NETWORK must be set to "testnet" or "mainnet"')
        process.exit(1)
      }

      // Security check for mainnet
      if (network === 'mainnet' && process.env.NODE_ENV !== 'production') {
        console.error('❌ Mainnet deployment requires NODE_ENV=production')
        process.exit(1)
      }

      console.log(`✅ Building for ${network} network`)
    }

    return config
  },
}

module.exports = nextConfig