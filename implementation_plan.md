# Super Admin Workflow Fix — Implementation Plan

## Summary

The project already has most of the Super Admin infrastructure in place, but
uses the old naming (`faculty_admin`) throughout the codebase.  
The requested change renames the **UI concept** of "Faculty Admin" → "Admin"
while keeping the backend role value `admin` (formerly `faculty_admin`) for the
pending-approval workflow.

### Key semantic mapping

| UI label | Backend `role` value |
|---|---|
| Student | `student` |
| Contributor | `contributor` |
| **Admin** (new) | **`admin`** (NEW role for pending-approval admin) |
| *(hidden)* Super Admin | `super_admin` |
| *(legacy, kept for compat)* | `admin` → renamed to avoid collision — see note below |

> **IMPORTANT note on role names:** The current code has two conflicting uses of `admin`:
> - Legacy `admin` — a simple admin with no pending flow.
> - The new "Admin" that the user wants pending approval — currently called `faculty_admin`.
>
> **Decision:** Since the user says "Admin in the UI = backend role `admin` (Faculty Admin)",
> the simplest approach is to **repurpose `admin` as the pending-approval role** and
> **drop the legacy `admin` role** (or keep it as an internal fallback without UI entry).  
> After discussion, the safest approach (no DB migration) is:
> - Keep `faculty_admin` as the backend role value for the approval workflow.
> - Rename **only the UI labels** from "Faculty Admin" → "Admin".
> - The login chip says "Admin" but sends `role = 'faculty_admin'` to the backend.
> - Registration role chip "Admin" calls `registerFacultyAdmin` as before.
> - The old `admin` (legacy) role is completely hidden from the UI.

## Proposed Changes

---

### Backend

#### [MODIFY] [authController.js](file:///d:/Varsity%20Projects/EduShare/backend/controllers/authController.js)
- Fix login status-pending message: replace "Faculty Admin" wording with "Admin".
- Accept `faculty_admin` in login (already works, just update error messages).

#### [MODIFY] [superAdminController.js](file:///d:/Varsity%20Projects/EduShare/backend/controllers/superAdminController.js)
- Add `verifiedBy` / `verifiedAt` fields on approve.
- Add `rejectionReason` field on reject (keep user record with `status = 'rejected'` instead of deleting).
- Add notification triggers: `notifyAdminOnApproval`, `notifyAdminOnRejection`.
- Add `notifySuperAdminOnNewAdmin` call from `registerFacultyAdmin`.

#### [MODIFY] [notificationService.js](file:///d:/Varsity%20Projects/EduShare/backend/services/notificationService.js)
- Add `notifyAdminOnApproval({ admin, superAdmin })`.
- Add `notifyAdminOnRejection({ admin, superAdmin, reason })`.
- Add `notifySuperAdminOnNewAdmin({ admin })` — finds the super_admin user and creates notification.

#### [MODIFY] [Notification.js](file:///d:/Varsity%20Projects/EduShare/backend/models/Notification.js)
- Expand `type` enum to include: `admin_registered`, `admin_approved`, `admin_rejected`.

#### [MODIFY] [User.js](file:///d:/Varsity%20Projects/EduShare/backend/models/User.js)
- Add `rejectionReason` field (String, default null).
- Add `verifiedBy` (ObjectId ref User, default null).
- Add `verifiedAt` (Date, default null).

#### [MODIFY] [authController.js](file:///d:/Varsity%20Projects/EduShare/backend/controllers/authController.js)
- In `registerFacultyAdmin`: after creating user, call `notifySuperAdminOnNewAdmin`.
- Update login error message wording (remove "Faculty Admin").
- The `SELF_REGISTER_ROLES` already excludes `faculty_admin` from generic register — good.

#### [MODIFY] [materialController.js](file:///d:/Varsity%20Projects/EduShare/backend/controllers/materialController.js)
- `findFacultyAdminForDept` already works correctly — no change needed to query logic.

---

### Flutter

#### [MODIFY] [login_screen.dart](file:///d:/Varsity%20Projects/EduShare/lib/views/auth/login_screen.dart)
- **Remove** Row 2 chips: `faculty_admin` ("Faculty Admin") and `super_admin` ("Super Admin").
- Row 1 remains: Student · Contributor · Admin (but Admin chip sends `faculty_admin` role).
- The `_selectedRole` default remains `student`.
- Admin chip label = "Admin", sends `role = 'faculty_admin'` to the backend.

#### [MODIFY] [register_screen.dart](file:///d:/Varsity%20Projects/EduShare/lib/views/auth/register_screen.dart)
- Remove `faculty_admin` chip from role selector; replace label "Faculty Admin" → "Admin".
- The role option "Admin" triggers `_isFacultyAdmin` (backend: `registerFacultyAdmin`).
- Remove old `admin` / `faculty_admin` string references from labels.
- Update pending notice text: "reviewed by the Admin" → "reviewed by the Super Admin".

#### [MODIFY] [pending_approval_screen.dart](file:///d:/Varsity%20Projects/EduShare/lib/views/auth/pending_approval_screen.dart)
- Update label: "Faculty Admin application" → "Admin application".
- Step 3: "Once approved, log in as **Admin**" (not Faculty Admin).

#### [MODIFY] [faculty_admins_screen.dart](file:///d:/Varsity%20Projects/EduShare/lib/views/admin/faculty_admins_screen.dart)
- Rename all visible text: "Faculty Admin" → "Admin".
- AppBar title: "Admins" (not "Faculty Admins").
- Tab labels: "Pending" / "All Admins".
- Card texts updated.
- **Add rejection reason** dialog with a text field (currently just confirms, does not collect reason).
- After reject, passes reason to `rejectFacultyAdmin(id, reason)`.

#### [MODIFY] [firestore_service.dart](file:///d:/Varsity%20Projects/EduShare/lib/core/services/firestore_service.dart)
- Update `rejectFacultyAdmin(String id)` → `rejectFacultyAdmin(String id, {String? reason})` — passes reason in PUT body.

#### [MODIFY] [main_shell.dart](file:///d:/Varsity%20Projects/EduShare/lib/views/shell/main_shell.dart)
- In the tab builder, rename label "Faculty Admins" → "Admins" for super_admin tab.
- The `faculty_admin` case tab label can stay internal (users never see "faculty admin" label).

#### [MODIFY] [role_helper.dart](file:///d:/Varsity%20Projects/EduShare/lib/core/role_helper.dart)
- `roleLabel` for `faculty_admin` → "Admin" (not "Faculty Admin").
- `roleLabel` for `admin` → "Admin (Legacy)".

#### [MODIFY] [adminController.js](file:///d:/Varsity%20Projects/EduShare/backend/controllers/adminController.js)
- `getPendingMaterials` / `getAllMaterials` / `getStats` already filter by `faculty_admin` role — no change needed.

---

### Backend — routes update

#### [MODIFY] [superAdminRoutes.js](file:///d:/Varsity%20Projects/EduShare/backend/routes/superAdminRoutes.js)
- Update `rejectFacultyAdmin` route to accept body `{ reason }`.

---

## Verification Plan

### Manual
1. Login screen shows exactly 3 chips: Student, Contributor, Admin.
2. Clicking Admin chip sends `faculty_admin` role; login works for approved faculty_admin accounts.
3. Pending faculty_admin cannot log in — receives the correct error message.
4. Registering as Admin goes through pending approval flow.
5. Super Admin dashboard shows new pending Admin registrations in real time.
6. Approve/Reject with reason — notifications created correctly.
7. Material upload assigns to the correct department Admin.

### Automated
- None (no test suite present).
