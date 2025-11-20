# 🎯 Governance Simplification - Impact Report

## Executive Summary

**Objective**: Remove complex DAO proposal governance, keep only gauge voting for emissions allocation.

**Approach**: Streamline to pure ve(3,3) flywheel - lock → vote on gauges → earn bribes. Team controls parameters via multisig with time delays.

---

## 📊 Impact Analysis

### ✅ **KEEP** - Core ve(3,3) Flywheel

| Component | File(s) | Reason |
|-----------|---------|--------|
| **veNFT Locking** | `contracts/veNFT.sol` | Core voting power mechanism |
| **Gauge Voting** | `src/app/vote/gauges/page.tsx` | Weekly emissions allocation (THE ONLY VOTING) |
| **Bribe System** | `src/app/vote/create-bribe/page.tsx`<br/>`src/app/vote/bribes/page.tsx` | Incentivization mechanism |
| **Emissions** | Minter/EmissionScheduler contracts | Weekly epoch distributions |
| **DEX Core** | Pair/Factory/Router contracts | Trading infrastructure |
| **veNFT Management** | `src/app/venft/*` pages | Lock/unlock/manage interface |
| **Fee Distribution** | FeeDistributor contracts | LP & staker rewards |

### ❌ **REMOVE** - DAO/Proposal Governance

| Component | File(s) | Action |
|-----------|---------|--------|
| **Governance Contracts** | `contracts/MinimalGovernance.sol` | DELETE |
| **Governance Page** | `src/app/governance/page.tsx` | DELETE |
| **Governance Component** | `src/components/GovernanceDashboard.tsx` | DELETE |
| **Treasury Component** | `src/components/TreasuryDashboard.tsx` | DELETE |
| **Governance Hook** | `src/hooks/useGovernance.ts` | DELETE |
| **Vote Landing Page** | `src/app/vote/page.tsx` | REPLACE with redirect to /vote/gauges |
| **Governance Docs** | `docs/governance/DAO-governance-model.md` | UPDATE |
| **Governance Scripts** | `scripts/deploy-minimal-governance.js` | DELETE |
| **Header Nav Link** | UpdatedHeader governance link | REMOVE |

### 🔄 **MODIFY** - Update for Simplified Model

| Component | File(s) | Changes Required |
|-----------|---------|------------------|
| **Documentation** | `README.md`<br/>`WHITEPAPER.md`<br/>`docs/**/*.md` | Remove DAO references<br/>Add "Gauge-only governance" |
| **Frontend Nav** | `src/components/UpdatedHeader.tsx` | Remove Governance nav item |
| **Homepage** | `src/app/page.tsx` | Remove governance feature card |
| **veNFT Contract** | `contracts/veNFT.sol` | Remove `recordVote()` for proposals<br/>Keep only gauge voting |

### 🆕 **ADD** - Team Parameter Control

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| **AccessControl** | Role-based parameter management | Add `OPS_ROLE`, `EMISSIONS_ROLE` |
| **Timelock Modifiers** | 48-72h delay on parameter changes | Modifier on sensitive setters |
| **Parameter Bounds** | Prevent abuse | Max protocol fee = 1%<br/>Emission rate caps |
| **Events** | Transparency | `ProtocolFeeUpdated`<br/>`EmissionRateUpdated` |

---

## 🏗️ New Architecture

### **Before** (Complex DAO)
```
veNFT → Vote on Proposals → Execute via Timelock → Change Parameters
veNFT → Vote on Gauges → Allocate Emissions
veNFT → Vote on Treasury → Spend Funds
```

### **After** (Streamlined Gauge-Only)
```
veNFT → Vote on Gauges ONLY → Allocate Emissions → Earn Bribes
Team Multisig → Set Parameters (with 48h delay) → Protocol adjustments
```

---

## 📁 File-by-File Action Plan

### **Contracts**

#### DELETE
- ✅ `contracts/MinimalGovernance.sol` - Full proposal system

#### KEEP AS-IS
- ✅ `contracts/veNFT.sol` - May need minor cleanup of proposal voting references
- ✅ `contracts/Pair.sol`, `Factory.sol`, `Router.sol` - DEX core
- ✅ Gauge/Bribe contracts (when implemented)

#### ADD NEW
- ⏳ `contracts/access/RoleManager.sol` - AccessControl for ops
- ⏳ `contracts/governance/TimelockOperations.sol` - Delay parameter changes
- ⏳ `contracts/governance/ProtocolParameters.sol` - Bounded setters

### **Frontend**

#### DELETE Pages
```bash
rm src/app/governance/page.tsx
rm src/components/GovernanceDashboard.tsx
rm src/components/TreasuryDashboard.tsx
rm src/hooks/useGovernance.ts
```

#### MODIFY Pages
- `src/app/vote/page.tsx` - Change to redirect or simple gauge info
- `src/app/page.tsx` - Remove governance feature card
- `src/components/UpdatedHeader.tsx` - Remove governance nav link

#### KEEP AS-IS
- ✅ `src/app/vote/gauges/page.tsx` - THE core voting UI
- ✅ `src/app/vote/create-bribe/page.tsx`
- ✅ `src/app/vote/bribes/page.tsx`
- ✅ `src/app/venft/**` - All veNFT management

### **Documentation**

#### UPDATE
- `README.md` - Add "Gauge-Only Governance" section
- `WHITEPAPER.md` - Update governance model
- `docs/tokenomics/veNFT-system.md` - Focus on gauge voting
- `docs/governance/DAO-governance-model.md` - Rewrite as "Gauge Voting Guide"

#### ADD
- `ADR-GOVERNANCE-SIMPLIFICATION.md` - Architecture decision record
- `TEAM_OPERATIONS.md` - How team manages parameters

### **Scripts**

#### DELETE
- `scripts/deploy-minimal-governance.js`

#### ADD
- `scripts/ops/set-protocol-fee.js` - Team parameter setter
- `scripts/ops/update-emission-rate.js`

---

## 🔒 Security Guardrails

### **Parameter Bounds**
```solidity
// Protocol fee can't exceed 1%
function setProtocolFeeBips(uint16 bips) external onlyRole(OPS_ROLE) onlyTimelocked {
    require(bips <= 100, "Max 1%");
    protocolFeeBips = bips;
    emit ProtocolFeeUpdated(bips);
}

// Fee split must equal 100%
function setFeeSplit(
    uint16 lp, uint16 stakers, uint16 treasury, uint16 burn
) external onlyRole(OPS_ROLE) onlyTimelocked {
    require(lp + stakers + treasury + burn == 10000, "Must equal 100%");
    // ... set values
    emit FeeSplitUpdated(lp, stakers, treasury, burn);
}

// Emission rate capped
function setEmissionRate(uint256 perEpoch) external onlyRole(EMISSIONS_ROLE) onlyTimelocked {
    require(perEpoch <= MAX_EMISSION, "Exceeds cap");
    emissionRate = perEpoch;
    emit EmissionRateUpdated(perEpoch);
}
```

### **Timelock Delays**
- 48 hours for non-critical parameters (fees, splits)
- 72 hours for critical parameters (emission rates, epoch length)
- Emergency 12-hour bypass (requires 3/5 multisig)

---

## ✅ Acceptance Criteria

**Contracts:**
- [ ] No `propose()`, `castVote()`, `execute()` functions exist
- [ ] Gauge voting fully functional (veNFT → vote allocation → emissions)
- [ ] Bribe deposit/claim works correctly
- [ ] All parameter setters have bounds and emit events
- [ ] Timelock delays enforced on sensitive operations

**Frontend:**
- [ ] `/governance` route removed
- [ ] `/vote` redirects to `/vote/gauges`
- [ ] Gauge voting page fully functional
- [ ] Bribe creation/claiming UI works
- [ ] No "Create Proposal" buttons anywhere

**Documentation:**
- [ ] README states "Gauge-only governance"
- [ ] ADR explains why we removed DAO governance
- [ ] Team operations guide published
- [ ] All docs updated to reflect new model

**Tests:**
- [ ] Gauge voting test suite passes
- [ ] Bribe mechanics tested
- [ ] Parameter bounds tested
- [ ] Timelock delays verified
- [ ] E2E: User can lock → vote gauges → claim bribes

---

## 🎯 Migration Steps (In Order)

1. ✅ **Create this impact report**
2. ⏳ **Update contracts:**
   - Add AccessControl roles
   - Add timelock modifiers
   - Add parameter bounds
   - Remove MinimalGovernance.sol
3. ⏳ **Remove frontend governance:**
   - Delete governance pages/components
   - Update navigation
   - Redirect /vote to /vote/gauges
4. ⏳ **Update documentation:**
   - README updates
   - ADR creation
   - Governance docs rewrite
5. ⏳ **Write tests:**
   - Gauge voting tests
   - Parameter setter tests
   - E2E user journey
6. ⏳ **Deploy and verify:**
   - Testnet deployment
   - Verify gauge voting works
   - Verify team can set parameters

---

## 🚀 Expected Outcomes

**Benefits:**
- ✅ 90% reduction in governance complexity
- ✅ Faster decision making (no proposal delays)
- ✅ Reduced regulatory risk (no DAO)
- ✅ Clearer user experience (one type of voting)
- ✅ Smaller attack surface
- ✅ Lower gas costs (no proposal storage/execution)

**What We Keep:**
- ✅ ve(3,3) flywheel (lock → vote → earn)
- ✅ Gauge voting (direct emissions to pools)
- ✅ Bribes (protocols incentivize votes)
- ✅ All veNFT features (locking, evolution, trading)

**What We Remove:**
- ❌ Complex proposal system
- ❌ Treasury voting
- ❌ Parameter governance voting
- ❌ Political complexity
- ❌ Governance overhead

---

## 📊 Summary Table

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Voting Types | 3 (Proposals, Gauges, Treasury) | 1 (Gauges only) | -67% |
| Contracts | MinimalGovernance + others | None | -1 contract |
| Frontend Pages | 7 governance pages | 3 gauge pages | -57% |
| Decision Latency | 7 days (proposal period) | Immediate (team action) | 100% faster |
| User Complexity | High (what to vote on?) | Low (vote for pools) | Much simpler |
| Regulatory Risk | Medium (DAO concerns) | Low (gauge allocation) | Reduced |

---

**Status**: Ready for implementation ✅
**Next Step**: Begin contract modifications (Step 2)
