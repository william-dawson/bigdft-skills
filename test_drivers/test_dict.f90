!> Test driver: Dictionary operations
!! Exercises creation, setting, getting, nesting, lists, iteration, and cleanup.
program test_dict
  use futile
  implicit none

  type(dictionary), pointer :: dict, nested, iter, list_dict
  character(len=256) :: sval
  integer :: ival, n
  real(f_double) :: dval

  call f_lib_initialize()

  ! --- Basic creation and set/get ---
  call dict_init(dict)
  call set(dict // 'name', 'water')
  call set(dict // 'natoms', 3)
  call set(dict // 'energy', -76.4d0)
  call set(dict // 'converged', 'yes')

  call yaml_mapping_open('Basic Dict Test')
  sval = dict // 'name'
  call yaml_map('Name', trim(sval))
  ival = dict // 'natoms'
  call yaml_map('Natoms', ival)
  dval = dict // 'energy'
  call yaml_map('Energy', dval)
  call yaml_mapping_close()

  ! --- Nested dictionaries ---
  call set(dict // 'dft' // 'hgrids', 0.4d0)
  call set(dict // 'dft' // 'ixc', 'PBE')
  call set(dict // 'dft' // 'rmult' // 0, 5.0d0)
  call set(dict // 'dft' // 'rmult' // 1, 8.0d0)

  call yaml_mapping_open('Nested Dict Test')
  call yaml_map('DFT section', dict // 'dft')
  call yaml_mapping_close()

  ! --- Key existence ---
  call yaml_mapping_open('Key Existence Test')
  call yaml_map('Has name', ('name' .in. dict))
  call yaml_map('Has missing', ('missing' .in. dict))
  call yaml_map('Size of dict', dict_size(dict))
  call yaml_mapping_close()

  ! --- Iteration ---
  call yaml_sequence_open('Iteration Test')
  iter => dict_iter(dict)
  do while(associated(iter))
    call yaml_mapping_open()
    call yaml_map('key', trim(dict_key(iter)))
    call yaml_mapping_close()
    iter => dict_next(iter)
  end do
  call yaml_sequence_close()

  ! --- Dict dump ---
  call yaml_comment('Full dictionary dump:', hfill='-')
  call yaml_dict_dump(dict)

  ! --- Cleanup ---
  call dict_free(dict)

  call f_lib_finalize()
end program test_dict
