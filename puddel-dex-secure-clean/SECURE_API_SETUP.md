# Secure API Key Management

## 🔐 Security Architecture

This application uses a **server-side API key architecture** to ensure maximum security:

1. **API keys are NEVER exposed to the client/browser**
2. **API keys are NEVER visible in dev tools or network requests**
3. **API keys are ONLY accessible on the server**
4. **All AI requests go through secure API routes**

## 📋 Setup Instructions

### Step 1: Add Your API Key

In `.env.local`, add your Hugging Face API key:

```bash
# SERVER-SIDE ONLY (Secure)
HUGGINGFACE_API_KEY=hf_yourActualTokenHere

# NOT using NEXT_PUBLIC_ prefix = more secure!
```

### Step 2: Restart Your Dev Server

```bash
npm run dev
```

### Step 3: Test the Connection

The app will automatically use the secure API routes. You can verify it's working by:
1. Opening browser DevTools > Network tab
2. Using an AI feature
3. Confirming requests go to `/api/ai/chat` or `/api/ai/generate-image`
4. Confirming NO API keys are visible in requests

## 🛡️ Security Benefits

### What You're Protected From:

1. **Client-side exposure**: API keys never reach the browser
2. **DevTools inspection**: Keys not visible in browser tools
3. **Network sniffing**: Keys not in HTTP requests from browser
4. **Code inspection**: Keys not in minified JavaScript bundles
5. **Developer visibility**: Even developers working on the frontend can't see keys

### How It Works:

```
User Browser → Your API Route → Hugging Face API
     ↑              ↑                ↑
     |              |                |
  No API Key   Has API Key    Receives API Key
```

## 🔑 Key Management Best Practices

### Development (.env.local)
- Store keys in `.env.local` (gitignored)
- Use non-public environment variables (no `NEXT_PUBLIC_` prefix)
- Rotate keys regularly
- Use separate keys for dev/staging/production

### Production (Hosting Platform)
- **Vercel**: Add via Environment Variables in dashboard
- **Netlify**: Add via Site Settings > Environment Variables
- **AWS**: Use AWS Secrets Manager
- **Azure**: Use Azure Key Vault
- **Self-hosted**: Use environment variables or secret management tools

### Key Rotation Schedule
- **After exposure**: Immediately
- **Production keys**: Monthly
- **Development keys**: Quarterly
- **After team member leaves**: Within 24 hours

## 📝 Environment Variable Reference

### Secure (Server-side only)
```bash
HUGGINGFACE_API_KEY=hf_xxx        # ✅ Secure
OPENAI_API_KEY=sk-xxx             # ✅ Secure
ANTHROPIC_API_KEY=sk-ant-xxx      # ✅ Secure
REPLICATE_API_KEY=r8_xxx          # ✅ Secure
```

### Public (Client-side - Use Sparingly)
```bash
NEXT_PUBLIC_APP_NAME=PuddelSwap   # ✅ OK - Not sensitive
NEXT_PUBLIC_API_KEY=xxx           # ❌ Avoid - Exposed to client
```

## 🚨 Security Checklist

- [ ] API keys are in `.env.local`
- [ ] `.env.local` is in `.gitignore`
- [ ] No `NEXT_PUBLIC_` prefix on sensitive keys
- [ ] All AI calls go through `/api/ai/*` routes
- [ ] No API keys in client-side code
- [ ] No API keys committed to Git
- [ ] Production keys stored in hosting platform's secrets
- [ ] Different keys for dev/staging/production
- [ ] Keys rotated regularly

## 🔄 Migration from Public to Secure

If you previously used `NEXT_PUBLIC_` keys:

1. **Update `.env.local`**:
   ```bash
   # Old (Insecure)
   NEXT_PUBLIC_HUGGINGFACE_API_KEY=hf_xxx
   
   # New (Secure)
   HUGGINGFACE_API_KEY=hf_xxx
   ```

2. **Update your code** to use `secureAIService`:
   ```typescript
   // Old (Direct API calls)
   import { HuggingFaceService } from '@/services/huggingFaceService'
   const service = new HuggingFaceService(process.env.NEXT_PUBLIC_HUGGINGFACE_API_KEY)
   
   // New (Through API routes)
   import { secureAIService } from '@/services/secureAIService'
   const response = await secureAIService.chat('Hello')
   ```

3. **Rotate your keys** (since old ones may be exposed)

## 🐛 Troubleshooting

### "AI service not configured"
- Check that `HUGGINGFACE_API_KEY` is in `.env.local`
- Ensure NO `NEXT_PUBLIC_` prefix
- Restart dev server after adding key

### "Model is loading"
- Normal for Hugging Face free tier
- Wait 20-30 seconds and retry
- Models go to sleep after inactivity

### Network errors
- Check browser console for errors
- Verify `/api/ai/*` routes are accessible
- Check server logs for errors

## 📚 Additional Resources

- [Next.js Environment Variables](https://nextjs.org/docs/basic-features/environment-variables)
- [Vercel Environment Variables](https://vercel.com/docs/environment-variables)
- [OWASP API Security](https://owasp.org/www-project-api-security/)

## ⚠️ Never Do This

```javascript
// ❌ NEVER hardcode keys
const API_KEY = "hf_actualKeyHere"

// ❌ NEVER use public env vars for secrets
const key = process.env.NEXT_PUBLIC_SECRET_KEY

// ❌ NEVER log keys
console.log("API Key:", apiKey)

// ❌ NEVER commit .env.local
git add .env.local  // NO!
```

## ✅ Always Do This

```javascript
// ✅ Use server-side environment variables
const API_KEY = process.env.HUGGINGFACE_API_KEY

// ✅ Validate keys exist
if (!API_KEY) {
  throw new Error('API key not configured')
}

// ✅ Use try-catch for API calls
try {
  const response = await fetch(...)
} catch (error) {
  // Handle gracefully
}
```