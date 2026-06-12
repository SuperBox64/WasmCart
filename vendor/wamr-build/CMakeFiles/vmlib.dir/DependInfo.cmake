
# Consider dependencies only in project.
set(CMAKE_DEPENDS_IN_PROJECT_ONLY OFF)

# The set of languages for which implicit dependencies are needed:
set(CMAKE_DEPENDS_LANGUAGES
  "ASM"
  )
# The set of files for implicit dependencies of each language:
set(CMAKE_DEPENDS_CHECK_ASM
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/arch/invokeNative_aarch64.s" "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr-build/CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/arch/invokeNative_aarch64.s.o"
  )
set(CMAKE_ASM_COMPILER_ID "AppleClang")

# Preprocessor definitions for this target.
set(CMAKE_TARGET_DEFINITIONS_ASM
  "BH_FREE=wasm_runtime_free"
  "BH_MALLOC=wasm_runtime_malloc"
  "BH_PLATFORM_DARWIN"
  "BUILD_TARGET=\"AARCH64\""
  "BUILD_TARGET_AARCH64"
  "WASM_DISABLE_HW_BOUND_CHECK=0"
  "WASM_DISABLE_STACK_HW_BOUND_CHECK=0"
  "WASM_DISABLE_WAKEUP_BLOCKING_OP=0"
  "WASM_ENABLE_AOT_INTRINSICS=0"
  "WASM_ENABLE_BULK_MEMORY=1"
  "WASM_ENABLE_EXTENDED_CONST_EXPR=0"
  "WASM_ENABLE_FAST_INTERP=1"
  "WASM_ENABLE_INTERP=1"
  "WASM_ENABLE_LIBC_WASI=1"
  "WASM_ENABLE_MINI_LOADER=0"
  "WASM_ENABLE_MODULE_INST_CONTEXT=1"
  "WASM_ENABLE_MULTI_MODULE=0"
  "WASM_ENABLE_QUICK_AOT_ENTRY=0"
  "WASM_ENABLE_REF_TYPES=1"
  "WASM_ENABLE_SHARED_MEMORY=0"
  "WASM_ENABLE_SHRUNK_MEMORY=1"
  "WASM_GLOBAL_HEAP_SIZE=10485760"
  "WASM_HAVE_MREMAP=0"
  )

# The include file search paths:
set(CMAKE_ASM_TARGET_INCLUDE_PATH
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/include"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/product-mini/platforms/darwin/../../../core/iwasm/include"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/darwin"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/darwin/../include"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/libc-util"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/uncommon"
  )

# The set of dependency files which are needed:
set(CMAKE_DEPENDS_DEPENDENCY_FILES
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_application.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_application.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_application.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_blocking_op.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_blocking_op.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_blocking_op.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_c_api.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_c_api.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_c_api.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_exec_env.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_exec_env.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_exec_env.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_loader_common.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_loader_common.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_loader_common.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_memory.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_memory.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_memory.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_native.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_native.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_native.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_runtime_common.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_runtime_common.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_runtime_common.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_shared_memory.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_shared_memory.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/common/wasm_shared_memory.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_interp_fast.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_interp_fast.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_interp_fast.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_loader.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_loader.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_loader.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_runtime.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_runtime.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/interpreter/wasm_runtime.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/libc_wasi_wrapper.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/libc_wasi_wrapper.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/libc_wasi_wrapper.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/blocking_op.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/blocking_op.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/blocking_op.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/posix.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/posix.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/posix.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/random.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/random.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/random.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/str.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/str.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/str.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_alloc.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_alloc.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_alloc.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_gc.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_gc.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_gc.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_hmu.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_hmu.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_hmu.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_kfc.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_kfc.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/ems/ems_kfc.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/mem_alloc.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/mem_alloc.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/mem-alloc/mem_alloc.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/libc-util/libc_errno.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/libc-util/libc_errno.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/libc-util/libc_errno.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/memory/mremap.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/memory/mremap.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/memory/mremap.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_blocking_op.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_blocking_op.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_blocking_op.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_clock.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_clock.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_clock.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_file.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_file.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_file.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_malloc.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_malloc.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_malloc.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_memmap.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_memmap.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_memmap.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_sleep.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_sleep.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_sleep.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_socket.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_socket.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_socket.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_thread.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_thread.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_thread.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_time.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_time.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/common/posix/posix_time.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/darwin/platform_init.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/darwin/platform_init.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/platform/darwin/platform_init.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_assert.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_assert.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_assert.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_bitmap.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_bitmap.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_bitmap.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_common.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_common.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_common.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_hashmap.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_hashmap.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_hashmap.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_leb128.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_leb128.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_leb128.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_list.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_list.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_list.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_log.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_log.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_log.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_queue.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_queue.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_queue.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_vector.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_vector.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/bh_vector.c.o.d"
  "/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/runtime_timer.c" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/runtime_timer.c.o" "gcc" "CMakeFiles/vmlib.dir/Users/toddbruss/Documents/GitHub/WasmCart/vendor/wamr/core/shared/utils/runtime_timer.c.o.d"
  )

# Targets to which this target links which contain Fortran sources.
set(CMAKE_Fortran_TARGET_LINKED_INFO_FILES
  )

# Targets to which this target links which contain Fortran sources.
set(CMAKE_Fortran_TARGET_FORWARD_LINKED_INFO_FILES
  )

# Fortran module output directory.
set(CMAKE_Fortran_TARGET_MODULE_DIR "")
