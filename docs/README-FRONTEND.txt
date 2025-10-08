================================================================================
                    FRONTEND DEPLOYMENT - COMPLETE GUIDE
================================================================================

📚 THREE DOCUMENTS CREATED FOR YOU:

1. FRONTEND-DEPLOYMENT-PLAN.md (MAIN GUIDE - START HERE!)
   - 18 detailed tasks with code examples
   - Step-by-step instructions
   - Time estimates for each task
   - Complete implementation guide

2. FRONTEND-TASK-SUMMARY.md (QUICK REFERENCE)
   - Task checklist
   - Quick commands
   - Key files overview
   - Validation checklist

3. Updated docs/README.md
   - Added frontend deployment section
   - Quick links to guides

================================================================================
                            QUICK START PATH
================================================================================

READ IN THIS ORDER:

1. docs/FRONTEND-DEPLOYMENT-PLAN.md
   → Complete walkthrough with all code

2. Implement tasks 1-18 following the plan

3. Use FRONTEND-TASK-SUMMARY.md as checklist

4. Test with Task 18 validation

================================================================================
                        WHAT YOU'LL IMPLEMENT
================================================================================

Phase 1: Helm Chart Foundation
  ✓ Chart.yaml - Chart metadata
  ✓ values.yaml - Configuration (backend connection!)

Phase 2: Kubernetes Templates
  ✓ _helpers.tpl - Template functions
  ✓ deployment.yaml - Next.js deployment (with BACKEND_URL)
  ✓ service.yaml - Service on port 3000
  ✓ serviceaccount.yaml - Pod identity

Phase 3: Optional Templates
  ✓ Copy ingress.yaml, hpa.yaml, httproute.yaml from backend

Phase 4: Support Files
  ✓ .helmignore - Package exclusions
  ✓ NOTES.txt - Post-install help

Phase 5: Deployment Automation
  ✓ deploy-local.sh - Automated deployment script
  ✓ Make executable with chmod +x

Phase 6: Makefile Commands
  ✓ build-frontend - Build Docker image
  ✓ load-frontend - Load into cluster
  ✓ helm-frontend - Complete workflow
  ✓ pf-frontend - Port forward
  ✓ frontend-logs - View logs
  ✓ helm-fullstack - Deploy everything!

Phase 7: Documentation
  ✓ helm_charts/frontend/README.md - Chart docs
  ✓ helm_charts/frontend/QUICK-START.md - Quick guide
  ✓ Update main README.md - Frontend section

Phase 8: Testing
  ✓ Deploy backend first
  ✓ Deploy frontend
  ✓ Test integration

================================================================================
                        BACKEND CONNECTION
================================================================================

HOW IT WORKS:

1. values.yaml configuration:
   ```yaml
   backend:
     releaseName: "my-backend"  # Backend Helm release name
   ```

2. Helm generates environment variable:
   BACKEND_URL=http://my-backend:8000

3. Next.js API routes use this:
   ```typescript
   const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8000'
   fetch(`${BACKEND_URL}/items`)
   ```

4. Kubernetes DNS resolves "my-backend" to backend service

NO BUILD-TIME CONFIG NEEDED! Everything is runtime.

================================================================================
                        MAKE COMMANDS (AFTER SETUP)
================================================================================

# Frontend only
make helm-frontend          # Build + Load + Deploy
make pf-frontend           # Port forward to 3000
make frontend-logs         # View logs
make helm-destroy-frontend # Clean up

# Full stack
make helm-fullstack        # Deploy backend + frontend
make helm-destroy-fullstack # Destroy everything

# Access
kubectl port-forward svc/my-frontend 3000:3000
→ http://localhost:3000

================================================================================
                        TIME ESTIMATE
================================================================================

Total: ~3 hours 20 minutes

Breakdown:
- Chart setup: 30 min
- Templates: 30 min
- Scripts: 35 min
- Documentation: 1h 25min
- Testing: 20 min

================================================================================
                        KEY DECISIONS EXPLAINED
================================================================================

1. Runtime vs Build-time Backend URL
   ✓ CHOSE: Runtime environment variable
   WHY: No rebuild needed when backend URL changes
   
2. No Init Container for Frontend
   ✓ Frontend can start independently
   WHY: Fails gracefully, shows loading state

3. Service Discovery
   ✓ Use Kubernetes DNS (my-backend:8000)
   WHY: Works automatically, no IPs needed

4. Pattern Matching Backend
   ✓ Same chart structure as backend
   WHY: Consistency, easy to understand

================================================================================
                        START HERE
================================================================================

Open and read:
→ docs/FRONTEND-DEPLOYMENT-PLAN.md

This has ALL the code and instructions you need!

================================================================================
