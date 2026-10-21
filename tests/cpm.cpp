// Запуск тестовой программы CP/M (.COM) на эмуляторе КР580ВМ80А.
//
//   cpm <файл.COM> <строка успеха> [строка ошибки]
//
// Тест пройден, если программа завершилась, в её выводе есть строка успеха
// и нет строки ошибки. Из CP/M эмулируются только функции BDOS 2 и 9 (вывод).

#include "i8080.h"

#include <cstdio>
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <string>
#include <vector>

namespace
{
	constexpr uint16_t BDOS = 0xFE00;			// верх памяти для программы и обработчик BDOS
	constexpr uint64_t CHUNK = 9 * 1'000'000;	// кварц: 9 тактов на такт процессора
	constexpr uint64_t TIMEOUT = 9 * 100'000'000'000ULL;

	struct Machine : I8080::Core
	{
		uint8_t memory[0x10000]{};
		I8080 *cpu = nullptr;

		std::string output;
		bool done = false;

		void MEMW(uint16_t addr, uint8_t data, uint8_t) override
		{
			memory[addr] = data;
		}

		uint8_t MEMR(uint16_t addr, uint8_t) override
		{
			return memory[addr];
		}

		uint8_t IOR(uint16_t, uint8_t) override
		{
			return 0xFF;
		}

		void IOW(uint16_t addr, uint8_t, uint8_t) override
		{
			switch(addr & 0xFF)
			{
				case 0x00:	// WBOOT: программа завершилась
					done = true;
					break;

				case 0x01:	// BDOS
					if(cpu->C == 2)
						output += char(cpu->E);
					else if(cpu->C == 9)
						for(uint16_t p = cpu->DE; memory[p] != '$'; ++p)
							output += char(memory[p]);
					break;
			}
		}
	};
}

int main(int argc, char *argv[])
{
	if(argc < 3)
	{
		std::cerr << "usage: cpm <file.COM> <pass string> [fail string]\n";
		return 2;
	}

	std::ifstream file(argv[1], std::ios::binary);
	std::vector<uint8_t> program{std::istreambuf_iterator<char>(file), {}};

	if(!file && !file.eof() || program.empty() || program.size() > BDOS - 0x100)
	{
		std::cerr << "cannot load " << argv[1] << "\n";
		return 2;
	}

	auto machine = std::make_unique<Machine>();
	std::copy(program.begin(), program.end(), machine->memory + 0x100);

	const uint8_t wboot[] = {0xD3, 0x00, 0x76};				// OUT 00h; HLT
	const uint8_t bdos[] = {0xC3, BDOS & 0xFF, BDOS >> 8};	// JMP BDOS
	const uint8_t handler[] = {0xD3, 0x01, 0xC9};			// OUT 01h; RET

	std::copy(std::begin(wboot), std::end(wboot), machine->memory + 0x0000);
	std::copy(std::begin(bdos), std::end(bdos), machine->memory + 0x0005);
	std::copy(std::begin(handler), std::end(handler), machine->memory + BDOS);

	I8080 cpu(machine.get());
	machine->cpu = &cpu;

	cpu.reset();
	cpu.PC = 0x0100;
	cpu.SP = BDOS;

	while(!machine->done && machine->CLOCK < TIMEOUT)
		cpu.execute(machine->CLOCK + CHUNK);

	std::cout << machine->output << "\n";
	std::cout << "[" << machine->CLOCK / 9 << " cycles]\n";

	if(!machine->done)
	{
		std::cerr << "FAIL: timeout\n";
		return 1;
	}

	if(machine->output.find(argv[2]) == std::string::npos)
	{
		std::cerr << "FAIL: no \"" << argv[2] << "\" in output\n";
		return 1;
	}

	if(argc > 3 && machine->output.find(argv[3]) != std::string::npos)
	{
		std::cerr << "FAIL: \"" << argv[3] << "\" in output\n";
		return 1;
	}

	return 0;
}
