// Тесты дизассемблера и ассемблера libkr580

#include "dasm.h"

#include <cstdio>
#include <string>
#include <vector>

namespace
{
	int failures = 0;

	void check(bool ok, const std::string& what)
	{
		if(!ok)
		{
			std::printf("FAIL: %s\n", what.c_str());
			++failures;
		}
	}

	std::string hex(const std::vector<uint8_t>& bytes)
	{
		std::string s;
		char buf[4];

		for(auto b : bytes)
		{
			std::snprintf(buf, sizeof(buf), "%02X ", b);
			s += buf;
		}

		return s;
	}

	// Дизассемблировать bytes с адреса addr; за концом bytes читаются нули
	std::pair<std::vector<uint8_t>, std::string> disasm(const std::vector<uint8_t>& bytes, uint16_t addr = 0, bool z80 = false)
	{
		auto [data, text] = dasm(addr, [&](uint16_t a) -> std::optional<uint8_t> {
			uint16_t i = a - addr;
			return i < bytes.size() ? bytes[i] : 0;
		}, z80);

		std::vector<uint8_t> result;

		for(auto& b : data)
			result.push_back(b.value_or(0));

		return {result, text};
	}

	std::string withoutStar(std::string text)
	{
		std::erase(text, '*');
		return text;
	}

	// 8080: каждая команда переживает круг «дизассемблер → ассемблер».
	// Недокументированные коды (мнемоника со звёздочкой) ассемблер собирает
	// в один код группы, для NOP* это документированный 00. Поэтому для них
	// проверяется, что собралась та же команда
	void roundTrip8080()
	{
		for(int op = 0; op < 256; ++op)
		{
			auto [data, text] = disasm({uint8_t(op), 0x34, 0x12});
			auto bytes = assembly(text);

			if(text.find('*') == std::string::npos)
				check(bytes == data, hex(data) + "\"" + text + "\" -> " + hex(bytes));
			else
				check(!bytes.empty() && withoutStar(disasm(bytes).second) == withoutStar(text), hex(data) + "\"" + text + "\" -> " + hex(bytes));
		}
	}

	void z80()
	{
		struct { std::vector<uint8_t> bytes; uint16_t addr; const char *text; } cases[] = {
			{{0xED, 0xB0},             0x0000, "LDIR"},
			{{0xED, 0x4D},             0x0000, "RETI"},
			{{0x08},                   0x0000, "EX AF,AF'"},
			{{0xD9},                   0x0000, "EXX"},
			{{0xCB, 0x7E},             0x0000, "BIT 7,(HL)"},
			{{0x3A, 0x34, 0x12},       0x0000, "LD A,(1234)"},
			{{0x36, 0x55},             0x0000, "LD (HL),55"},
			{{0xDD, 0x21, 0x34, 0x12}, 0x0000, "LD IX,1234"},
			{{0xDD, 0x36, 0x05, 0x55}, 0x0000, "LD (IX+05),55"},
			{{0xDD, 0xCB, 0x05, 0x46}, 0x0000, "BIT 0,(IX+05)"},
			{{0xDD, 0xCB, 0x05, 0x06}, 0x0000, "RLC (IX+05)"},
			{{0x10, 0xFE},             0x1000, "DJNZ 1000"},
			{{0x18, 0x02},             0x1000, "JR 1004"},
		};

		for(auto& c : cases)
		{
			auto [data, text] = disasm(c.bytes, c.addr, true);
			check(data == c.bytes && text == c.text, hex(c.bytes) + "-> " + hex(data) + "\"" + text + "\", expected \"" + c.text + "\"");
		}
	}

	void unreadable()
	{
		// Нечитаемый байт операнда не теряется и показывается знаками вопроса
		auto [data, text] = dasm(0, [](uint16_t a) -> std::optional<uint8_t> {
			return a == 0 ? std::optional<uint8_t>(0x3A) : std::nullopt;
		});

		check(data.size() == 3 && !data[1] && !data[2] && text == "LDA ????", "unreadable operand: \"" + text + "\"");
	}

	void assemblerRejects()
	{
		for(auto source : {"FOO", "MVI A", "MVI Q,12", "MVI A,123", "JMP 12345", "MOV A,B,C"})
			check(assembly(source).empty(), std::string("assembly accepted \"") + source + "\"");
	}
}

int main()
{
	roundTrip8080();
	z80();
	unreadable();
	assemblerRejects();

	std::printf("%s\n", failures ? "FAILED" : "OK");
	return failures != 0;
}
