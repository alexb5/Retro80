##
## Тесты libkr580: ctest --test-dir <каталог сборки>
## Долгий 8080EXM помечен меткой long: ctest -LE long пропускает его
##

add_executable(test_dasm dasm.cpp)
target_link_libraries(test_dasm kr580)
add_test(NAME dasm COMMAND test_dasm)

# Классические тесты процессора 8080 для CP/M. Они под GPL, поэтому
# в репозитории не лежат, а скачиваются при конфигурации с проверкой хеша

option(RETRO80_CPU_TESTS "Download and run 8080 CPU exercisers" ON)

if(RETRO80_CPU_TESTS)

	add_executable(cpm cpm.cpp)
	target_link_libraries(cpm kr580)

	set(CPU_TESTS_URL https://raw.githubusercontent.com/superzazu/8080/274ffd700b81baabea99b0963bc1260b67132185/cpu_tests)

	#   имя|файл|хеш|строка успеха|строка ошибки
	set(CPU_TESTS
		"TST8080|TST8080.COM|9561c6fb6c99efe3de00eb77e4044fd102151058b39ac2d7bce10483838a08e7|CPU IS OPERATIONAL|"
		"8080PRE|8080PRE.COM|18eb3c79cba42c0718f160be6a1853cb64cdce7aa47d65780189a57bdd98c4e0|Preliminary tests complete|"
		"CPUTEST|CPUTEST.COM|e61a9a75348c774486c2207080ea4effbf6c2367fdace31b0731081a4144030b|CPU TESTS OK|"
		"8080EXM|8080EXM.COM|6e3286e11bb1a8f47b8ee1280b4a067be813193363e3223c99b0d21912f44aeb|Tests complete|ERROR")

	foreach(entry IN LISTS CPU_TESTS)

		string(REPLACE "|" ";" entry "${entry}")
		list(GET entry 0 name)
		list(GET entry 1 file)
		list(GET entry 2 hash)
		list(GET entry 3 pass)
		list(LENGTH entry count)

		set(path ${CMAKE_CURRENT_BINARY_DIR}/cpu_tests/${file})

		if(NOT EXISTS ${path})
			file(DOWNLOAD ${CPU_TESTS_URL}/${file} ${path}
				EXPECTED_HASH SHA256=${hash}
				STATUS status)

			list(GET status 0 code)

			if(NOT code EQUAL 0)
				file(REMOVE ${path})
				message(WARNING "${file}: download failed (${status}), CPU test ${name} skipped")
				continue()
			endif()
		endif()

		if(count GREATER 4)
			list(GET entry 4 fail)
		else()
			set(fail "")
		endif()

		if(NOT fail STREQUAL "")
			add_test(NAME cpu_${name} COMMAND cpm ${path} "${pass}" "${fail}")
		else()
			add_test(NAME cpu_${name} COMMAND cpm ${path} "${pass}")
		endif()

	endforeach()

	if(TEST cpu_8080EXM)
		set_tests_properties(cpu_8080EXM PROPERTIES LABELS long TIMEOUT 600)
	endif()

endif()
