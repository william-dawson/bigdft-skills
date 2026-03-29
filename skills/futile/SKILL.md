---
name: futile
description: Guide for writing Fortran code using the Futile library (dictionaries, memory management, YAML I/O, error handling, timing, MPI wrappers). Use when developing or modifying BigDFT Fortran source code.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep
---

# Futile Library Developer Guide

Futile is BigDFT's foundational Fortran utility library. It provides Python-like dictionaries, tracked memory allocation, YAML I/O, structured error handling, timing/profiling, and MPI wrappers. All BigDFT Fortran code uses these facilities.

This skill helps write correct Fortran code using futile conventions. When the user asks to write or modify Fortran code in the BigDFT codebase, apply these patterns.

## Program Structure

Every program or module using futile follows this skeleton:

```fortran
program my_program
  use futile
  implicit none

  ! Declarations...

  call f_lib_initialize()

  ! ... main code using futile facilities ...

  call f_lib_finalize()
end program
```

`f_lib_initialize()` sets up error handling, memory tracking, timing, and environment variables. `f_lib_finalize()` prints profiling reports and checks for memory leaks. Both are mandatory.

For subroutines/modules that are called from code already initialized, just `use futile` (or specific submodules) and skip init/finalize.

## Dictionaries

Futile dictionaries are the central data structure -- they map directly to YAML and Python dicts. They are pointer-based linked trees.

### Declaration

```fortran
type(dictionary), pointer :: dict, child, iter
```

Dictionaries **must** be declared as pointers.

### Creation and Cleanup

```fortran
! Empty dictionary
call dict_init(dict)

! From key-value pairs using .is. operator
dict => dict_new(['key1' .is. 'value1', 'key2' .is. 'value2'])

! From list items using .item. operator
dict => list_new([.item. 'first', .item. 'second', .item. 'third'])

! Cleanup -- frees all children recursively
call dict_free(dict)
```

### The // Operator (Key Access)

The `//` operator is the primary way to navigate and create dictionary entries. It returns a pointer to the child node, creating it if it doesn't exist:

```fortran
! Set values at any nesting depth
call set(dict // 'key', 'value')              ! string
call set(dict // 'key', 42)                   ! integer
call set(dict // 'key', 3.14d0)               ! double
call set(dict // 'key', .true.)               ! logical
call set(dict // 'key', (/1.0d0, 2.0d0/))    ! array
call set(dict // 'nested' // 'deep', 'val')   ! nested

! Access list items by index (0-based)
call set(dict // 0, 'first_item')
call set(dict // 1, 'second_item')
```

### Getting Values

Values are retrieved via assignment, which auto-converts types:

```fortran
character(len=256) :: sval
integer :: ival
real(f_double) :: dval
real(f_double), dimension(3) :: arr

sval = dict // 'key'              ! as string
ival = dict // 'key'              ! as integer
dval = dict // 'key'              ! as double
arr  = dict // 'array_key'        ! as array
```

Or explicitly:

```fortran
sval = dict_value(dict // 'key')  ! always returns string
```

### Querying

```fortran
! Check if key exists
if ('mykey' .in. dict) then ...
if ('mykey' .notin. dict) then ...
if (has_key(dict, 'mykey')) then ...

! Size
n = dict_len(dict)   ! number of items (for lists)
n = dict_size(dict)  ! number of keys (for mappings)

! Type testing
if (dict_isdict(dict // 'key')) then ...   ! is a nested dict?
if (dict_islist(dict // 'key')) then ...   ! is a list?
if (dict_isscalar(dict // 'key')) then ... ! is a scalar value?
```

### Iteration

```fortran
iter => dict_iter(dict)
do while(associated(iter))
  key = dict_key(iter)
  val = dict_value(iter)
  ! ... process ...
  iter => dict_next(iter)
end do
```

### Modification

```fortran
! Append to list
call add(dict, 'new_item')

! Remove key
call dict_remove(dict, 'key_to_remove')

! Pop (extract and remove)
child => dict .pop. 'key'
! ... use child ...
call dict_free(child)

! Deep copy
call dict_copy(dest, src)

! Merge (update dest with src values)
call dict_update(dest, src)
```

### Safe Access

```fortran
! .get. returns null if key missing (no error)
val = (dict .get. 'maybe_key')
```

## YAML Output

Futile can write structured YAML output directly from Fortran. This is used pervasively for logging and output.

### Key-Value Pairs

```fortran
use yaml_output

call yaml_map('Label', value)     ! works for all types
call yaml_map('Energy', -42.5d0)
call yaml_map('Converged', .true.)
call yaml_map('Grid', (/0.4d0, 0.4d0, 0.4d0/))
call yaml_map('Name', 'water')

! With format control
call yaml_map('Energy', -42.5d0, fmt='(f12.6)')
```

### Nested Mappings

```fortran
call yaml_mapping_open('Section')
  call yaml_map('key1', 'value1')
  call yaml_map('key2', 42)
  call yaml_mapping_open('Subsection')
    call yaml_map('nested_key', 3.14d0)
  call yaml_mapping_close()
call yaml_mapping_close()
```

Produces:
```yaml
Section:
  key1: value1
  key2: 42
  Subsection:
    nested_key: 3.14
```

### Sequences (Lists)

```fortran
call yaml_sequence_open('Items')
  call yaml_sequence(advance='no')
    call yaml_map('name', 'first')
  call yaml_sequence(advance='no')
    call yaml_map('name', 'second')
call yaml_sequence_close()
```

### Comments and Documents

```fortran
call yaml_comment('This is a comment')
call yaml_comment('Section Header', hfill='~')  ! fills line with ~
call yaml_new_document()
! ... content ...
call yaml_release_document()
```

### Dumping a Dictionary as YAML

```fortran
call yaml_dict_dump(dict)                     ! to stdout
call yaml_dict_dump(dict, unit=unt)           ! to file unit
call yaml_dict_dump(dict, flow=.true.)        ! compact style
```

## YAML Parsing

### From File

```fortran
use yaml_parse

type(dictionary), pointer :: dict
call yaml_parse_from_file(dict, 'input.yaml')
! ... use dict ...
call dict_free(dict)
```

### From String

```fortran
character(len=*), parameter :: yaml_str = &
  "key1: value1" // char(10) // &
  "key2: 42" // char(10) // &
  "nested:" // char(10) // &
  "  key3: hello"

call yaml_parse_from_string(dict, yaml_str)
```

### Quick Load

```fortran
dict => yaml_load("key1: value1, key2: 42")
```

## Memory Allocation

Futile replaces raw Fortran `allocate`/`deallocate` with tracked, profiled allocation.

### Basic Allocation

```fortran
real(f_double), dimension(:), allocatable :: arr
real(f_double), dimension(:,:), allocatable :: mat
integer, dimension(:), pointer :: iptr

! Allocate with tracking
arr = f_malloc(1000, id='arr')

! Allocate and zero-initialize
arr = f_malloc0(1000, id='arr')

! Multi-dimensional
mat = f_malloc((/100, 200/), id='mat')

! Pointer allocation
iptr = f_malloc_ptr(500, id='iptr')
iptr = f_malloc0_ptr(500, id='iptr')  ! zero-initialized

! Custom bounds
arr = f_malloc(1.to.100, id='arr')
mat = f_malloc((/0.to.99, 1.to.50/), id='mat')

! Deallocation
call f_free(arr)
call f_free(mat)
call f_free_ptr(iptr)
```

The `id=` parameter names the array for profiling reports. Always provide it.

### Supported Types and Ranks

Allocation works for all intrinsic types up to rank 7:
- `integer(f_integer)`, `integer(f_long)`
- `real(f_simple)`, `real(f_double)`
- `complex(f_double)`
- `logical`
- `character(len=*)`

Use futile kind parameters (`f_integer`, `f_long`, `f_double`, `f_simple`) from `f_precisions`.

### Routine-Level Profiling

```fortran
subroutine my_computation(n)
  use futile
  implicit none
  integer, intent(in) :: n
  real(f_double), dimension(:), allocatable :: work

  call f_routine(id='my_computation')

  work = f_malloc(n, id='work')
  ! ... compute ...
  call f_free(work)

  call f_release_routine()
end subroutine
```

`f_routine`/`f_release_routine` bracket a scope for memory and timing profiling. The profiling report at finalization groups allocations by routine.

### Utility Operations

```fortran
call f_zero(arr)                    ! zero-fill
call f_memcpy(dest=dst, src=src)    ! copy arrays
diff = f_maxdiff(arr1, arr2)        ! max element difference
nbytes = f_sizeof(arr)              ! size in bytes
addr = f_loc(arr)                   ! memory address
```

## Error Handling

Futile provides structured error handling with a try-catch pattern.

### Defining Errors

```fortran
integer :: ERR_MY_ERROR

call f_err_define( &
  err_name='ERR_MY_ERROR', &
  err_msg='Description of what went wrong', &
  err_action='Suggested recovery action', &
  err_id=ERR_MY_ERROR)
```

### Raising Errors

```fortran
! Conditional raise (most common pattern)
if (f_err_raise(n < 0, 'n must be non-negative', err_id=ERR_MY_ERROR)) return

! Unconditional throw
call f_err_throw('Something failed', err_id=ERR_MY_ERROR)
```

`f_err_raise` returns `.true.` if the error was raised, so the `if (...) return` pattern propagates the error to the caller.

### Checking and Retrieving Errors

```fortran
! Check if any error occurred
if (f_err_check()) then ...

! Check for specific error
if (f_err_check(err_id=ERR_MY_ERROR)) then ...
if (f_err_check(err_name='ERR_MY_ERROR')) then ...

! Get last error
ierr = f_get_last_error(msg)

! Pop error from stack
call f_err_pop(err_id=ierr, add_msg=msg)

! Count errors
n = f_get_no_of_errors()
```

### Try-Catch Pattern

```fortran
type(dictionary), pointer :: exceptions

call f_err_open_try()

  ! Code that might raise errors
  call risky_operation()

call f_err_close_try(exceptions)

if (associated(exceptions)) then
  ! Handle errors -- exceptions is a dictionary of errors
  call yaml_dict_dump(exceptions)
  call dict_free(exceptions)
end if
```

Try blocks can be nested. Each level captures errors independently.

### Error Callbacks

```fortran
! Set custom handler
call f_err_set_callback(my_handler)
! ... code that might error ...
call f_err_unset_callback()

! Override severe error behavior (default: abort)
call f_err_severe_override(my_severe_handler)
! ... code ...
call f_err_severe_restore()
```

## Timing and Profiling

### Defining Categories

```fortran
integer :: TCAT_MY_OPERATION

call f_timing_category_group('MyModule', 'Description of timing group')
call f_timing_category('My Operation', 'MyModule', &
     'What this operation does', TCAT_MY_OPERATION)
```

### Timing Code Sections

```fortran
! Method 1: Profile scope
call f_profile(TCAT_MY_OPERATION)
! ... timed code ...
call f_profile_end(TCAT_MY_OPERATION)

! Method 2: Manual timing
call f_timing(TCAT_MY_OPERATION, 'ON')
! ... timed code ...
call f_timing(TCAT_MY_OPERATION, 'OF')
```

### Wall Clock

```fortran
integer(f_long) :: t0, t1

t0 = f_time()                              ! nanoseconds
! ... work ...
t1 = f_time()
call yaml_map('Elapsed (s)', real(t1 - t0, f_double) * 1.d-9)
call yaml_map('Elapsed', f_humantime(t1 - t0))  ! human-readable
```

## MPI Wrappers

### Initialization

```fortran
use wrapper_MPI

call mpiinit()
iproc = mpirank()
nproc = mpisize()
```

### MPI Environment Type

```fortran
type(mpi_environment) :: mpi_env

call mpi_environment_set(mpi_env, MPI_COMM_WORLD)
! mpi_env%iproc, mpi_env%nproc available
```

### Collective Operations

```fortran
! Allreduce (sum)
call fmpi_allreduce(buffer, op=FMPI_SUM)

! Allreduce into specific destination
call fmpi_allreduce(sendbuf, recvbuf, FMPI_SUM)

! Barrier
call fmpi_barrier()

! Get communicator
comm = fmpi_comm()
```

Futile MPI wrappers handle profiling and error checking automatically.

### Fake MPI

When compiled without MPI, futile provides `MPIfake` with no-op stubs so serial code compiles without `#ifdef` guards.

## String Utilities

### YAML String Conversion

```fortran
use yaml_strings

character(len=256) :: s

s = yaml_toa(42)           ! integer to string
s = yaml_toa(3.14d0)       ! double to string
s = yaml_toa(.true.)       ! logical to string
s = yaml_toa((/1,2,3/))   ! array to string
```

### String Operations

```fortran
! Concatenation with type conversion (// operator overloaded)
s = 'Value is ' // yaml_toa(42)

! Case-insensitive comparison
if ('PBE' .eqv. 'pbe') then ...

! Copy (handles length mismatch safely)
call f_strcpy(dest, src)
```

## Precision Types

Always use futile's portable kind parameters:

```fortran
use f_precisions

integer(f_integer) :: i        ! 32-bit integer
integer(f_long) :: li          ! 64-bit integer
real(f_simple) :: r            ! single precision
real(f_double) :: d            ! double precision
```

## Enumerators

Futile enumerators associate strings with integers:

```fortran
use f_enums

type(f_enumerator) :: method

method = f_enumerator('FIRE', 1, null())

! Compare with integer or string
if (method == 1) then ...
if (method == 'FIRE') then ...

! Convert
ival = toi(method)    ! to integer
sval = toa(method)    ! to string
```

## Reference Counting

For objects that need shared ownership:

```fortran
use f_refcnts

type(f_reference_counter) :: ref

ref = f_ref_new('my_object')
if (f_associated(ref)) then ...
call f_unref(ref, count)    ! decrement, get remaining count
call f_ref_free(ref)        ! release when count reaches 0
```

## Common Patterns in BigDFT Code

### Input Variable Processing

BigDFT reads input as YAML into a dictionary, then extracts values:

```fortran
type(dictionary), pointer :: dict, input

call yaml_parse_from_file(dict, 'input.yaml')

! Extract with defaults
if ('dft' .in. dict) then
  hgrid = dict // 'dft' // 'hgrids'
end if
```

### Logging with YAML

All BigDFT output uses YAML formatting for machine-readable logs:

```fortran
call yaml_mapping_open('Ground State Energy')
  call yaml_map('Total Energy (Ha)', etot)
  call yaml_map('Converged', gnrm < gnrm_cv)
  call yaml_map('Iterations', iter)
call yaml_mapping_close()
```

### Typical Subroutine Pattern

```fortran
subroutine my_bigdft_routine(n, input_dict, result)
  use futile
  implicit none
  integer, intent(in) :: n
  type(dictionary), pointer, intent(in) :: input_dict
  real(f_double), intent(out) :: result
  !local
  real(f_double), dimension(:), allocatable :: work
  integer :: TCAT_WORK

  call f_routine(id='my_bigdft_routine')

  ! Timing
  call f_timing_category('Work', 'MyModule', 'Main work', TCAT_WORK)
  call f_profile(TCAT_WORK)

  ! Allocation
  work = f_malloc(n, id='work')

  ! Read parameters from input dictionary
  if ('threshold' .in. input_dict) then
    threshold = input_dict // 'threshold'
  else
    threshold = 1.d-4  ! default
  end if

  ! ... computation ...

  ! Cleanup
  call f_free(work)
  call f_profile_end(TCAT_WORK)
  call f_release_routine()
end subroutine
```

## Quick Reference

| Task | Code |
|------|------|
| Init library | `call f_lib_initialize()` |
| Finalize library | `call f_lib_finalize()` |
| Create dict | `call dict_init(d)` / `d => dict_new(...)` |
| Free dict | `call dict_free(d)` |
| Set value | `call set(d // 'key', value)` |
| Get value | `val = d // 'key'` |
| Key exists? | `if ('key' .in. d)` |
| Iterate | `it => dict_iter(d); do while(associated(it)); it => dict_next(it); end do` |
| Allocate | `arr = f_malloc(n, id='arr')` |
| Allocate+zero | `arr = f_malloc0(n, id='arr')` |
| Free | `call f_free(arr)` |
| Alloc pointer | `ptr = f_malloc_ptr(n, id='ptr')` |
| Free pointer | `call f_free_ptr(ptr)` |
| Profile routine | `call f_routine(id='name')` ... `call f_release_routine()` |
| Raise error | `if (f_err_raise(cond, 'msg', err_id=E)) return` |
| Try-catch | `call f_err_open_try()` ... `call f_err_close_try(exc)` |
| YAML output | `call yaml_map('key', value)` |
| YAML section | `call yaml_mapping_open('S')` ... `call yaml_mapping_close()` |
| Parse YAML | `call yaml_parse_from_file(d, 'file.yaml')` |
| Timer | `t0 = f_time()` ... `elapsed = f_time() - t0` |
| Profile timing | `call f_profile(cat_id)` ... `call f_profile_end(cat_id)` |
| MPI allreduce | `call fmpi_allreduce(buf, op=FMPI_SUM)` |
