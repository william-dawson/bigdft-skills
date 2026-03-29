!> Test driver: Error handling
!! Exercises f_err_define, f_err_raise, try-catch, and error inspection.
program test_errors
  use futile
  implicit none

  type(dictionary), pointer :: exceptions
  integer :: ERR_NEGATIVE, ERR_OVERFLOW, ierr
  character(len=256) :: msg

  call f_lib_initialize()

  ! --- Define custom errors ---
  call f_err_define( &
    err_name='ERR_NEGATIVE', &
    err_msg='A negative value was encountered', &
    err_action='Check input values', &
    err_id=ERR_NEGATIVE)

  call f_err_define( &
    err_name='ERR_OVERFLOW', &
    err_msg='Value exceeds maximum allowed', &
    err_action='Reduce input size', &
    err_id=ERR_OVERFLOW)

  call yaml_mapping_open('Error Handling Tests')

  ! --- Test: raise and check ---
  call yaml_mapping_open('Raise and Check')
  call f_err_open_try()
    if (f_err_raise(.true., 'Testing negative error', &
        err_id=ERR_NEGATIVE)) then
      ! error was raised
    end if
    call yaml_map('Error occurred', f_err_check())
    call yaml_map('Is ERR_NEGATIVE', f_err_check(err_id=ERR_NEGATIVE))
    call yaml_map('Is ERR_OVERFLOW', f_err_check(err_id=ERR_OVERFLOW))
    ierr = f_get_last_error(msg)
    call yaml_map('Last error id', ierr)
    call yaml_map('Last error msg', trim(msg))
  call f_err_close_try()
  call yaml_mapping_close()

  ! --- Test: conditional raise (no error) ---
  call yaml_mapping_open('No Error Case')
  call f_err_open_try()
    if (f_err_raise(.false., 'This should not trigger', &
        err_id=ERR_OVERFLOW)) then
      call yaml_map('Should not see this', .true.)
    end if
    call yaml_map('Error occurred', f_err_check())
  call f_err_close_try()
  call yaml_mapping_close()

  ! --- Test: nested try-catch ---
  call yaml_mapping_open('Nested Try-Catch')
  call f_err_open_try()
    call f_err_throw('Outer error', err_id=ERR_NEGATIVE)
    call yaml_map('Outer error count', f_get_no_of_errors())

    call f_err_open_try()
      call f_err_throw('Inner error', err_id=ERR_OVERFLOW)
      call yaml_map('Inner error count', f_get_no_of_errors())
    call f_err_close_try(exceptions)
    if (associated(exceptions)) then
      call yaml_map('Inner exceptions caught', .true.)
      call dict_free(exceptions)
    end if
  call f_err_close_try(exceptions)
  if (associated(exceptions)) then
    call yaml_map('Outer exceptions caught', .true.)
    call dict_free(exceptions)
  end if
  call yaml_mapping_close()

  call yaml_mapping_close()

  call f_lib_finalize()
end program test_errors
