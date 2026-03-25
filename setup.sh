#!/bin/bash

# NAND Guardian - Quick Setup Script
# This script automates the initial setup of NAND Guardian frontend

set -e

echo "🔷 NAND Guardian - Frontend Setup"
echo "===================================="
echo ""

# Check Node.js
echo "✓ Checking Node.js..."
if ! command -v node &> /dev/null; then
    echo "  ✗ Node.js is not installed"
    echo "  Install from: https://nodejs.org/"
    exit 1
fi
NODE_VERSION=$(node -v)
echo "  ✓ Node.js $NODE_VERSION"

# Check npm
echo "✓ Checking npm..."
NPM_VERSION=$(npm -v)
echo "  ✓ npm $NPM_VERSION"

echo ""
echo "📦 Installing dependencies..."
npm install
echo "  ✓ Dependencies installed"

echo ""
echo "✓ Setup Complete!"
echo ""
echo "🚀 Next Steps:"
echo ""
echo "  1. Start development server:"
echo "     npm run dev"
echo ""
echo "  2. Open in browser:"
echo "     http://localhost:5173"
echo ""
echo "  3. To connect to backend API:"
echo "     - Start your backend on http://localhost:8000"
echo "     - Click 'Mock Mode' toggle in the header to switch to 'API Mode'"
echo ""
echo "📝 Documentation:"
echo "  - README.md                  (Project overview & features)"
echo "  - BACKEND_INTEGRATION.md     (For ML/backend engineers)"
echo "  - STRUCTURE.md               (Architecture & components)"
echo ""
echo "💡 Tips:"
echo "  - npm run build              (Production build)"
echo "  - npm run preview            (Preview production build)"
echo "  - Check tailwind.config.js   (Customize colors/theme)"
echo ""
echo "Happy coding! 🎉"
