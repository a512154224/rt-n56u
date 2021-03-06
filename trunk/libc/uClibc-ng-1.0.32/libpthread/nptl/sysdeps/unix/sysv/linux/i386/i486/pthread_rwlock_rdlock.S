/* Copyright (C) 2002, 2003, 2007 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@redhat.com>, 2002.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include <sysdep.h>
#include <lowlevellock.h>
#include <lowlevelrwlock.h>
#include <pthread-errnos.h>
#include <bits/kernel-features.h>
#include <tls.h>


	.text

	.globl	__pthread_rwlock_rdlock
	.type	__pthread_rwlock_rdlock,@function
	.protected	__pthread_rwlock_rdlock
	.align	16
__pthread_rwlock_rdlock:
	cfi_startproc
	pushl	%esi
	cfi_adjust_cfa_offset(4)
	pushl	%ebx
	cfi_adjust_cfa_offset(4)
	cfi_offset(%esi, -8)
	cfi_offset(%ebx, -12)

	xorl	%esi, %esi
	movl	12(%esp), %ebx

	/* Get the lock.  */
	movl	$1, %edx
	xorl	%eax, %eax
	LOCK
#if MUTEX == 0
	cmpxchgl %edx, (%ebx)
#else
	cmpxchgl %edx, MUTEX(%ebx)
#endif
	jnz	1f

2:	movl	WRITER(%ebx), %eax
	testl	%eax, %eax
	jne	14f
	cmpl	$0, WRITERS_QUEUED(%ebx)
	je	5f
	cmpb	$0, FLAGS(%ebx)
	je	5f

3:	addl	$1, READERS_QUEUED(%ebx)
	je	4f

	movl	READERS_WAKEUP(%ebx), %edx

	LOCK
#if MUTEX == 0
	subl	$1, (%ebx)
#else
	subl	$1, MUTEX(%ebx)
#endif
	jne	10f

11:
#ifdef __ASSUME_PRIVATE_FUTEX
	movzbl	PSHARED(%ebx), %ecx
	xorl	$FUTEX_PRIVATE_FLAG|FUTEX_WAIT, %ecx
#else
	movzbl	PSHARED(%ebx), %ecx
# if FUTEX_WAIT != 0
	orl	$FUTEX_WAIT, %ecx
# endif
	xorl	%gs:PRIVATE_FUTEX, %ecx
#endif
	addl	$READERS_WAKEUP, %ebx
	movl	$SYS_futex, %eax
	ENTER_KERNEL

	subl	$READERS_WAKEUP, %ebx

	/* Reget the lock.  */
	movl	$1, %edx
	xorl	%eax, %eax
	LOCK
#if MUTEX == 0
	cmpxchgl %edx, (%ebx)
#else
	cmpxchgl %edx, MUTEX(%ebx)
#endif
	jnz	12f

13:	subl	$1, READERS_QUEUED(%ebx)
	jmp	2b

5:	xorl	%edx, %edx
	addl	$1, NR_READERS(%ebx)
	je	8f
9:	LOCK
#if MUTEX == 0
	subl	$1, (%ebx)
#else
	subl	$1, MUTEX(%ebx)
#endif
	jne	6f
7:

	movl	%edx, %eax
	popl	%ebx
	cfi_adjust_cfa_offset(-4)
	cfi_restore(%ebx)
	popl	%esi
	cfi_adjust_cfa_offset(-4)
	cfi_restore(%esi)
	ret

	cfi_adjust_cfa_offset(8)
	cfi_offset(%esi, -8)
	cfi_offset(%ebx, -12)
1:
#if MUTEX == 0
	movl	%ebx, %edx
#else
	leal	MUTEX(%ebx), %edx
#endif
	movzbl	PSHARED(%ebx), %ecx
	call	__lll_lock_wait
	jmp	2b

14:	cmpl	%gs:TID, %eax
	jne	3b
	/* Deadlock detected.  */
	movl	$EDEADLK, %edx
	jmp	9b

6:
#if MUTEX == 0
	movl	%ebx, %eax
#else
	leal	MUTEX(%ebx), %eax
#endif
	movzbl	PSHARED(%ebx), %ecx
	call	__lll_unlock_wake
	jmp	7b

	/* Overflow.  */
8:	subl	$1, NR_READERS(%ebx)
	movl	$EAGAIN, %edx
	jmp	9b

	/* Overflow.  */
4:	subl	$1, READERS_QUEUED(%ebx)
	movl	$EAGAIN, %edx
	jmp	9b

10:
#if MUTEX == 0
	movl	%ebx, %eax
#else
	leal	MUTEX(%ebx), %eax
#endif
	movzbl	PSHARED(%ebx), %ecx
	call	__lll_unlock_wake
	jmp	11b

12:
#if MUTEX == 0
	movl	%ebx, %edx
#else
	leal	MUTEX(%ebx), %edx
#endif
	movzbl	PSHARED(%ebx), %ecx
	call	__lll_lock_wait
	jmp	13b
	cfi_endproc
	.size	__pthread_rwlock_rdlock,.-__pthread_rwlock_rdlock

	.globl	pthread_rwlock_rdlock
pthread_rwlock_rdlock = __pthread_rwlock_rdlock

	.globl	__pthread_rwlock_rdlock_internal
__pthread_rwlock_rdlock_internal = __pthread_rwlock_rdlock
