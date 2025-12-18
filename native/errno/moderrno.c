/*
 * moderrno.c - Extension to MicroPython's errno module
 *
 * Adds missing CPython-compatible errno constants:
 *   - ENOTDIR (20) - Not a directory
 *   - ENOSPC (28) - No space left on device
 *   - ESRCH (3) - No such process
 *   - ECHILD (10) - No child processes
 *   - EINTR (4) - Interrupted system call
 *   - EPIPE (32) - Broken pipe
 *   - ENOEXEC (8) - Exec format error
 *   - ENXIO (6) - No such device or address
 *   - E2BIG (7) - Argument list too long
 *   - EFAULT (14) - Bad address
 *   - EBUSY (16) - Device or resource busy
 *   - ENOTBLK (15) - Block device required
 *   - EXDEV (18) - Cross-device link
 *   - ENFILE (23) - File table overflow
 *   - EMFILE (24) - Too many open files
 *   - ENOTTY (25) - Not a typewriter
 *   - ETXTBSY (26) - Text file busy
 *   - EFBIG (27) - File too large
 *   - ESPIPE (29) - Illegal seek
 *   - EROFS (30) - Read-only file system
 *   - EMLINK (31) - Too many links
 */

#include "py/runtime.h"
#include <errno.h>

// Delegation handler for errno module attribute lookup
void errno_ext_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    (void)self_in;
    
    // Missing errno constants from CPython
    if (attr == MP_QSTR_ENOTDIR) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ENOTDIR);
    } else if (attr == MP_QSTR_ENOSPC) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ENOSPC);
    } else if (attr == MP_QSTR_ESRCH) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ESRCH);
    } else if (attr == MP_QSTR_ECHILD) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ECHILD);
    } else if (attr == MP_QSTR_EINTR) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EINTR);
    } else if (attr == MP_QSTR_EPIPE) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EPIPE);
    } else if (attr == MP_QSTR_ENOEXEC) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ENOEXEC);
    } else if (attr == MP_QSTR_ENXIO) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ENXIO);
    } else if (attr == MP_QSTR_E2BIG) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(E2BIG);
    } else if (attr == MP_QSTR_EFAULT) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EFAULT);
    } else if (attr == MP_QSTR_EBUSY) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EBUSY);
    } else if (attr == MP_QSTR_ENOTBLK) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ENOTBLK);
    } else if (attr == MP_QSTR_EXDEV) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EXDEV);
    } else if (attr == MP_QSTR_ENFILE) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ENFILE);
    } else if (attr == MP_QSTR_EMFILE) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EMFILE);
    } else if (attr == MP_QSTR_ENOTTY) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ENOTTY);
    } else if (attr == MP_QSTR_ETXTBSY) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ETXTBSY);
    } else if (attr == MP_QSTR_EFBIG) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EFBIG);
    } else if (attr == MP_QSTR_ESPIPE) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(ESPIPE);
    } else if (attr == MP_QSTR_EROFS) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EROFS);
    } else if (attr == MP_QSTR_EMLINK) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(EMLINK);
    }
}

// Declare external reference to mp_module_errno
extern const mp_obj_module_t mp_module_errno;

// Register as delegate/extension to the errno module
MP_REGISTER_MODULE_DELEGATION(mp_module_errno, errno_ext_attr);
