if (VCPKG_LIBRARY_LINKAGE STREQUAL dynamic AND VCPKG_CRT_LINKAGE STREQUAL static)
    message(STATUS "Warning: Dynamic library with static CRT is not supported. Building static library.")
    set(VCPKG_LIBRARY_LINKAGE static)
endif()

set(PYTHON_VERSION_MAJOR  3)
set(PYTHON_VERSION_MINOR  8)
set(PYTHON_VERSION_PATCH  3)
set(PYTHON_VERSION        ${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}.${PYTHON_VERSION_PATCH})

vcpkg_from_github(
    OUT_SOURCE_PATH TEMP_SOURCE_PATH
    REPO python/cpython
    REF v${PYTHON_VERSION}
    SHA512 eb264a858ef55f2f61b53f663454be6e99ffe9035d8fcdb3366d7a08fd3b295613e5d15e93e2e4b9b18ad297d8c17139bde5e90e396db04fe04c6f441a443fd2
    HEAD_REF master
	PATCHES python-all.patch
)


if("enable-shared" IN_LIST FEATURES)
	set(_ENABLED_SHARED --enable-shared)
else()
	unset(_ENABLED_SHARED)
endif()

if (VCPKG_TARGET_IS_WINDOWS)
	if(DEFINED _ENABLED_SHARED)
		message(WARNING "enable-shared requested, by Windows build already produce a shared library by default")
	endif()
	set(SOURCE_PATH "${TEMP_SOURCE_PATH}-Lib-Win")
	file(REMOVE_RECURSE ${SOURCE_PATH})
	file(RENAME "${TEMP_SOURCE_PATH}" ${SOURCE_PATH})

	# We need per-triplet directories because we need to patch the project files differently based on the linkage
	# Because the patches patch the same file, they have to be applied in the correct order

	if (VCPKG_TARGET_ARCHITECTURE MATCHES "x86")
		set(BUILD_ARCH "Win32")
		set(OUT_DIR "win32")
	elseif (VCPKG_TARGET_ARCHITECTURE MATCHES "x64")
		set(BUILD_ARCH "x64")
		set(OUT_DIR "amd64")
	else()
		message(FATAL_ERROR "Unsupported architecture: ${VCPKG_TARGET_ARCHITECTURE}")
	endif()
		
	vcpkg_find_acquire_program(GIT)
	
	vcpkg_execute_required_process(
		COMMAND cmd.exe /C "${SOURCE_PATH}/PCbuild/get_externals_.bat" "${GIT}"
		WORKING_DIRECTORY ${SOURCE_PATH}/PCBuild
		LOGNAME get_python_build_externals-${TARGET_TRIPLET}-dbg
		ALLOW_IN_DOWNLOAD_MODE)
		
	vcpkg_build_msbuild(
		PROJECT_PATH ${SOURCE_PATH}/PCBuild/pcbuild.proj
		PLATFORM ${BUILD_ARCH}
		OPTIONS /p:IncludeExternals=true /p:IncludeCTypes=true /p:IncludeSSL=true /p:IncludeTkinter=true)

	# install python public headers
	file(GLOB HEADERS ${SOURCE_PATH}/Include/*.h)
	file(GLOB CPYTHON_HEADERS ${SOURCE_PATH}/Include/cpython/*.h)
	file(INSTALL
			${HEADERS}
			"${SOURCE_PATH}/PC/pyconfig.h"
		DESTINATION
			"${CURRENT_PACKAGES_DIR}/include/python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}"
	)
	file(INSTALL
			${CPYTHON_HEADERS}
		DESTINATION
			"${CURRENT_PACKAGES_DIR}/include/python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}/cpython"
	)
	
	# install shared libraries
	set(
		PYTHON38_SHARED_BINARIES_PATTERNS
		"libcrypto*.dll;libffi*.dll;libssl*.dll;tcl86t.dll;tk86t.dll;vcruntime140*.dll"
	)
	set(PYTHON38_SHARED_BINARIES="")
	foreach(PATTERN ${PYTHON38_SHARED_BINARIES_PATTERNS})
		file(GLOB BINARIES ${SOURCE_PATH}/PCBuild/${OUT_DIR}/${PATTERN})
		file(INSTALL ${BINARIES} DESTINATION "${CURRENT_PACKAGES_DIR}/share/bin")
		set(PYTHON38_SHARED_BINARIES "${BINARIES};${PYTHON38_SHARED_BINARIES}")
	endforeach()
	
	# install python packages
	file(
		INSTALL
			"${SOURCE_PATH}/Lib"
		DESTINATION
			"${CURRENT_PACKAGES_DIR}/share/python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}"
	)
	file(GLOB PYD ${SOURCE_PATH}/PCBuild/${OUT_DIR}/*.pyd)
	file(
		INSTALL 
			${PYD} 
		DESTINATION 
			"${CURRENT_PACKAGES_DIR}/share/python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}/lib"
		PATTERN "*_d.pyd" EXCLUDE
	)

	# install compiled binaries and libraries
	file(GLOB PY_EXEC ${SOURCE_PATH}/PCBuild/${OUT_DIR}/*.exe)
	file(GLOB PY_DLL ${SOURCE_PATH}/PCBuild/${OUT_DIR}/*.dll)
	list(REMOVE_ITEM PY_DLL ${PYTHON38_SHARED_BINARIES})
	file(GLOB PY_LIB ${SOURCE_PATH}/PCBuild/${OUT_DIR}/python*.lib)
	if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
		file(
			INSTALL 
				${PY_EXEC} 
			DESTINATION 
				${CURRENT_PACKAGES_DIR}/exe
			PATTERN "*_d.exe" EXCLUDE
		)
		file(
			INSTALL 
				${PY_DLL} 
			DESTINATION 
				${CURRENT_PACKAGES_DIR}/bin
			PATTERN "*_d.dll" EXCLUDE
		)
		
		file(
			INSTALL 
				${PY_LIB} 
			DESTINATION 
				${CURRENT_PACKAGES_DIR}/lib
			PATTERN "*_dstub.lib" EXCLUDE
			PATTERN "*_d.lib" EXCLUDE
		)
	endif()
	if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
		file(
			INSTALL 
				${PY_EXEC} 
			DESTINATION 
				${CURRENT_PACKAGES_DIR}/debug/exe
			FILES_MATCHING PATTERN "*_d.exe"
		)
		file(
			INSTALL 
				${PY_DLL} 
			DESTINATION 
				${CURRENT_PACKAGES_DIR}/debug/bin
			FILES_MATCHING PATTERN "*_d.dll"
		)
		file(
			INSTALL
				${PY_LIB}
			DESTINATION 
				${CURRENT_PACKAGES_DIR}/debug/lib
			FILES_MATCHING PATTERN "*_d*.lib"
		)
	endif()

	# Handle copyright
	file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/python3-full RENAME copyright)

elseif (VCPKG_TARGET_IS_LINUX OR VCPKG_TARGET_IS_OSX)

	message(FATAL_ERROR "Unsupported platform: linux/osx")

endif()
