# Hugging Face API Key Setup - IMPORTANT FIX REQUIRED

## 🚨 Your Current Issue
Your API key is being rejected with "Invalid credentials" error. The key format is correct but the token appears to be invalid or expired.

## Generate a New Valid API Key (WITH CORRECT PERMISSIONS)

1. **Go to Hugging Face Settings**
   - Visit: https://huggingface.co/settings/tokens
   - Log in to your account
   
2. **Delete Old Token (if exists)**
   - Find any existing tokens for this project
   - Delete them to avoid confusion

3. **Create New Token - IMPORTANT: Use Fine-grained Token**
   - Click "New token" 
   - Name it: "Puddel-DEX-Production"
   - **Token type**: Choose "Fine-grained" (not "Read")
   - **Permissions**: 
     - ✅ Check "Make calls to the serverless Inference API"
     - ✅ Check "Access gated repos you have access to"
   - Click "Generate token"

4. **CRITICAL: Copy the Full Token**
   - The token is shown ONLY ONCE
   - Copy the ENTIRE token (starts with `hf_`)
   - Should be approximately 37 characters
   - DO NOT close the page until you've saved it

## Add to Vercel (Production)

1. **Go to Vercel Dashboard**
   - Open your project in Vercel
   - Go to Settings → Environment Variables

2. **Update the Variable**
   - Find `HUGGINGFACE_API_KEY` (NO "NEXT_PUBLIC_" prefix!)
   - Click Edit
   - Clear the field completely
   - Paste your new token
   - Make sure there are NO spaces before or after
   - Click Save

3. **Redeploy**
   - Vercel should auto-redeploy
   - Or go to Deployments → Redeploy latest

## Test Your New Key

After deployment completes, test at:
```
https://your-app.vercel.app/api/ai/test-key
```

Success response should show:
```json
{
  "success": true,
  "message": "API key is valid and working!",
  "whoami": { "type": "user", "name": "your-username" },
  "testResult": "[generated text]"
}
```

## Common Issues & Solutions

### ❌ "Invalid credentials in Authorization header" (YOUR CURRENT ISSUE)
**Root Cause**: Simple "Read" tokens don't work for Inference API
**Solution**: You need a **Fine-grained token** with **"Make calls to the serverless Inference API"** permission

### ❌ Token looks correct but still fails
**Possible causes**:
1. **Wrong token type** - Must be Fine-grained, not Read-only
2. **Missing inference permissions** - Must have API call permissions
3. Token was partially copied (missing characters)
4. Exceeded monthly free credits (check your HF account)
5. Accidental space/newline when pasting

### ❌ Works locally but not on Vercel
**Check**:
- Variable name is exactly `HUGGINGFACE_API_KEY` (no NEXT_PUBLIC prefix)
- No quotes around the token value in Vercel
- Redeployed after saving the variable

## Features Available After Fix

### AI Chat Assistant
- **Cost**: 0.1 PEL per message (FREE in dev mode)
- **Models Used**: 
  - Mistral-7B for general chat
  - Zephyr-7B for helpful responses
  - Microsoft Phi-2 for technical queries
- **Use Cases**: Get creative suggestions, color recommendations, composition tips

### Image Generation
- **Cost**: 1 PEL per image (FREE in dev mode)
- **Models Available**:
  - Stable Diffusion XL (best quality)
  - Stable Diffusion 2.1 (balanced)
  - Stable Diffusion 1.5 (fastest)
  - Anime/Manga styles (Waifu Diffusion)
  - Pixel Art (specialized for NFTs)
  - Cartoon/Comic styles
- **Features**: Multiple art styles, negative prompts, style modifiers

### Style Transfer
- **Cost**: 0.5 PEL per transformation (FREE in dev mode)
- **Apply artistic styles to existing artwork**

### Layer Enhancement
- **Cost**: 0.3 PEL per enhancement (FREE in dev mode)
- **AI-powered suggestions for improving layers**

## Free Tier Limits

Hugging Face provides generous free tier limits:
- **30,000 API requests per month**
- **Model Loading**: First request may take 20-30 seconds (models need to warm up)
- **Concurrent Requests**: Limited to a few at a time
- **No credit card required**

## Troubleshooting

### "Model is loading" Message
This is normal for the free tier. Models go to sleep after inactivity and need 20-30 seconds to wake up. The app handles this gracefully with loading placeholders.

### No AI Response
1. Check that your API key is correctly set in `.env.local`
2. Verify the key starts with `hf_`
3. Check console for error messages
4. Ensure you haven't exceeded monthly limits

### Image Generation Fails
- Some complex prompts may timeout on free tier
- Try simpler prompts or use the "fastest" model (SD 1.5)
- Check negative prompt isn't too restrictive

## Development Mode

By default, the app runs with `NEXT_PUBLIC_BYPASS_PAYMENTS=true`, which means:
- All AI features are FREE (no PEL required)
- You can test all functionality without tokens
- Perfect for development and testing

To test with payment simulation, set:
```
NEXT_PUBLIC_BYPASS_PAYMENTS=false
```

## Switching AI Providers

If you want to use a different AI service, update `.env.local`:

### OpenAI
```
NEXT_PUBLIC_AI_PROVIDER=openai
NEXT_PUBLIC_OPENAI_API_KEY=sk-...
```

### Anthropic Claude
```
NEXT_PUBLIC_AI_PROVIDER=claude
NEXT_PUBLIC_ANTHROPIC_API_KEY=sk-ant-...
```

### Local Ollama (Free, No API Key)
```
NEXT_PUBLIC_AI_PROVIDER=ollama
NEXT_PUBLIC_OLLAMA_URL=http://localhost:11434
```

### Mock Mode (No API Required)
```
NEXT_PUBLIC_AI_PROVIDER=mock
```

## Best Practices

1. **Start with Mock Mode**: Test UI/UX without API costs
2. **Use Hugging Face for Development**: Best free tier available
3. **Consider OpenAI for Production**: Better quality, but costs money
4. **Cache Responses**: Implement caching to reduce API calls
5. **Monitor Usage**: Track API calls to stay within limits

## Model Selection Strategy

The app automatically selects the best model based on context:

### Chat Models
- **Technical/Code**: Microsoft Phi-2 (optimized for technical content)
- **Creative/Story**: Mistral-7B (best for creative writing)
- **Help/Explain**: Zephyr-7B (optimized for helpful responses)
- **Default**: OpenChat 3.5 (GPT-3.5 alternative)

### Image Models
- **Anime/Manga**: Waifu Diffusion
- **Pixel Art**: Pixel Art XL (perfect for NFTs)
- **Cartoon/Comic**: Comic Diffusion
- **Abstract/Surreal**: Robo Diffusion
- **Fantasy/Dreamlike**: Dreamlike Diffusion
- **Artistic**: OpenJourney v4
- **Default**: Stable Diffusion 2.1

## Cost Optimization Tips

1. **Use Specific Styles**: The app selects optimal models automatically
2. **Batch Requests**: Generate multiple variations at once
3. **Cache Results**: Store generated images for reuse
4. **Optimize Prompts**: Shorter, clearer prompts work better
5. **Use Negative Prompts**: Improve quality without extra API calls

## Security Notes

- API keys are only used client-side (for demo purposes)
- In production, move API calls to server-side API routes
- Never commit `.env.local` to version control
- Rotate API keys regularly
- Monitor for unusual usage patterns