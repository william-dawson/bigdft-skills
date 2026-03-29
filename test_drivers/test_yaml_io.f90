!> Test driver: YAML output and parsing
!! Exercises yaml_map, yaml_mapping_open/close, yaml_sequence, and yaml_parse.
program test_yaml_io
  use futile
  implicit none

  type(dictionary), pointer :: dict, parsed
  real(f_double), dimension(3) :: coords
  character(len=*), parameter :: nl = char(10)

  call f_lib_initialize()

  ! --- Structured YAML output ---
  call yaml_mapping_open('Molecule')
    call yaml_map('name', 'water')
    call yaml_map('formula', 'H2O')
    call yaml_map('charge', 0)
    call yaml_map('multiplicity', 1)

    call yaml_mapping_open('dft')
      call yaml_map('functional', 'PBE')
      call yaml_map('hgrids', 0.4d0)
      call yaml_map('rmult', (/5.0d0, 8.0d0/))
      call yaml_map('converged', .true.)
    call yaml_mapping_close()

    call yaml_sequence_open('atoms')
      call yaml_sequence(advance='no')
        call yaml_mapping_open()
          call yaml_map('element', 'O')
          coords = (/0.0d0, 0.0d0, 0.119d0/)
          call yaml_map('position', coords)
        call yaml_mapping_close()
      call yaml_sequence(advance='no')
        call yaml_mapping_open()
          call yaml_map('element', 'H')
          coords = (/0.0d0, 0.757d0, -0.476d0/)
          call yaml_map('position', coords)
        call yaml_mapping_close()
      call yaml_sequence(advance='no')
        call yaml_mapping_open()
          call yaml_map('element', 'H')
          coords = (/0.0d0, -0.757d0, -0.476d0/)
          call yaml_map('position', coords)
        call yaml_mapping_close()
    call yaml_sequence_close()
  call yaml_mapping_close()

  ! --- Build a dict and dump it ---
  call yaml_comment('Dictionary built programmatically:', hfill='-')
  call dict_init(dict)
  call set(dict // 'code', 'BigDFT')
  call set(dict // 'version', '1.9.5')
  call set(dict // 'features' // 0, 'wavelets')
  call set(dict // 'features' // 1, 'linear scaling')
  call set(dict // 'features' // 2, 'GPU support')
  call yaml_dict_dump(dict)
  call dict_free(dict)

  ! --- Parse YAML from string ---
  call yaml_comment('Parsed from string:', hfill='-')
  call yaml_parse_from_string(parsed, &
    'method: FIRE' // nl // &
    'nsteps: 50' // nl // &
    'threshold: 1.0e-5' // nl)
  call yaml_dict_dump(parsed)
  call dict_free(parsed)

  call f_lib_finalize()
end program test_yaml_io
