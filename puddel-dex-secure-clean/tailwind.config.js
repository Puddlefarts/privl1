/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f4f0ff',
          100: '#ebe5ff',
          200: '#d6ccff',
          300: '#b8a3ff',
          400: '#9470ff',
          500: '#7c3aed',
          600: '#6d28d9',
          700: '#5b21b6',
          800: '#4c1d95',
          900: '#3c1677',
        },
        dark: {
          50: '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          900: '#0f172a',
        }
      },
      fontFamily: {
        sans: ['var(--font-inter)', 'system-ui', 'sans-serif'],
        display: ['var(--font-orbitron)', 'system-ui', 'sans-serif'],
        mono: ['var(--font-jetbrains)', 'Menlo', 'monospace'],
      },
      animation: {
        'glow-pulse': 'glowPulse 2s ease-in-out infinite alternate',
        'float': 'float 6s ease-in-out infinite',
        'slide-in-left': 'slideInLeft 0.5s ease-out',
        'slide-in-right': 'slideInRight 0.5s ease-out',
        'fade-in-up': 'fadeInUp 0.6s ease-out',
        'scale-in': 'scaleIn 0.4s ease-out',
        'cyber-flicker': 'cyberFlicker 3s ease-in-out infinite',
        'neural-pulse': 'neuralPulse 4s ease-in-out infinite',
        'data-stream': 'dataStream 2s linear infinite',
        'hologram-shimmer': 'hologramShimmer 3s ease-in-out infinite',
        'quantum-spin': 'quantumSpin 8s linear infinite',
      },
      keyframes: {
        glowPulse: {
          '0%': {
            boxShadow: '0 0 20px rgba(34, 211, 238, 0.3), 0 0 40px rgba(168, 85, 247, 0.1)',
            transform: 'scale(1)'
          },
          '100%': {
            boxShadow: '0 0 40px rgba(34, 211, 238, 0.6), 0 0 80px rgba(168, 85, 247, 0.3)',
            transform: 'scale(1.02)'
          }
        },
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-10px)' }
        },
        slideInLeft: {
          '0%': { transform: 'translateX(-100%)', opacity: '0' },
          '100%': { transform: 'translateX(0)', opacity: '1' }
        },
        slideInRight: {
          '0%': { transform: 'translateX(100%)', opacity: '0' },
          '100%': { transform: 'translateX(0)', opacity: '1' }
        },
        fadeInUp: {
          '0%': { transform: 'translateY(30px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' }
        },
        scaleIn: {
          '0%': { transform: 'scale(0.8)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' }
        },
        cyberFlicker: {
          '0%, 98%': { opacity: '1' },
          '99%': { opacity: '0.8' },
          '100%': { opacity: '1' }
        },
        neuralPulse: {
          '0%, 100%': {
            background: 'linear-gradient(45deg, rgba(34, 211, 238, 0.1), rgba(168, 85, 247, 0.1))',
            transform: 'scale(1)'
          },
          '50%': {
            background: 'linear-gradient(45deg, rgba(34, 211, 238, 0.3), rgba(168, 85, 247, 0.3))',
            transform: 'scale(1.05)'
          }
        },
        dataStream: {
          '0%': { transform: 'translateX(-100%)' },
          '100%': { transform: 'translateX(100%)' }
        },
        hologramShimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' }
        },
        quantumSpin: {
          '0%': { transform: 'rotate(0deg) scale(1)' },
          '25%': { transform: 'rotate(90deg) scale(1.1)' },
          '50%': { transform: 'rotate(180deg) scale(1)' },
          '75%': { transform: 'rotate(270deg) scale(0.9)' },
          '100%': { transform: 'rotate(360deg) scale(1)' }
        }
      },
      backgroundImage: {
        'cyber-grid': 'linear-gradient(rgba(34, 211, 238, 0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(34, 211, 238, 0.1) 1px, transparent 1px)',
        'neural-net': 'radial-gradient(circle at 25% 25%, rgba(168, 85, 247, 0.2) 0%, transparent 50%), radial-gradient(circle at 75% 75%, rgba(34, 211, 238, 0.2) 0%, transparent 50%)',
        'hologram': 'linear-gradient(45deg, transparent 30%, rgba(255, 255, 255, 0.1) 50%, transparent 70%)',
        'quantum-field': 'conic-gradient(from 0deg, rgba(34, 211, 238, 0.3), rgba(168, 85, 247, 0.3), rgba(34, 211, 238, 0.3))',
      },
      backdropBlur: {
        'cyber': '8px',
      },
      boxShadow: {
        'cyber': '0 0 20px rgba(34, 211, 238, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.1)',
        'neural': '0 8px 32px rgba(168, 85, 247, 0.3), 0 4px 16px rgba(34, 211, 238, 0.2)',
        'hologram': '0 0 40px rgba(34, 211, 238, 0.4), 0 0 80px rgba(168, 85, 247, 0.2)',
        'data-glow': 'inset 0 1px 0 rgba(255, 255, 255, 0.1), 0 1px 3px rgba(0, 0, 0, 0.3), 0 4px 20px rgba(34, 211, 238, 0.4)',
        'quantum': '0 0 60px rgba(168, 85, 247, 0.4), 0 0 100px rgba(34, 211, 238, 0.3)',
      }
    },
  },
  darkMode: 'class',
  plugins: [],
}