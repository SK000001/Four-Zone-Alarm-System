/*
 * 3b run c.c
 *
 * Created: 15/09/2022 8:25:36 PM
 * Author : 61481
 */ 

#include <avr/io.h>
#define F_CPU 12000000UL
#include <util/delay.h>

#define ddrKeypad DDRC
#define portKeypad PORTC
#define pinKeypad PINC
#define ddrLed DDRB
#define portLed PORTB
#define pinLed PINB

// global variables
uint8_t temp, temp2, output = 0x00, flag = 0;   // 0 - just 1 key, 1 - 1st key for password entry, 2 - 2nd key for password entry
uint8_t colIdle = 0xff;

uint8_t cols[] = {0xef, 0xdf, 0xbf, 0x7f};

uint8_t table[] = {	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255,		13, 255, 255, 255, 12, 255, 11, 10, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255,		15, 255, 255, 255, 9, 255, 6, 3, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255,		0, 255, 255, 255, 8, 255, 5, 2,  255,
					255, 255, 255, 255, 255, 255, 255,		14, 255, 255, 255, 7, 255, 4, 1, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255};
					
uint8_t passcode[] = {0x12, 0x34, 0x56};
uint8_t passcodeInput[3];

void errorBlink() {
	uint8_t t = PINB;
	PORTB = 0x00;
	_delay_ms(1000);
	PORTB = 0xFF;
	_delay_ms(1000);
	PORTB = 0x00;
	_delay_ms(1000);
	PORTB = 0xFF;
	_delay_ms(1000);
	PORTB = t;
}

void passblink() {
	PORTB |= 0x20;
	_delay_ms(500);
	PORTB &= 0xDF;
	_delay_ms(500);
	PORTB |= 0x20;
}

void passcodeVerification() {
	for (uint8_t K=0; K<3; K++) {
		if (passcode[K] != passcodeInput[K]) {
			errorBlink();
			PORTB &= 0x0F;
			if (PORTB == 15) {
				PORTB |= 0x90;
			}
			return;
		}
	}
	PORTB <<= 4;
	PORTB = ~PORTB;
	PORTB >>= 4;
	
	if (PORTB == 15) { PORTB |= 0x90; } else { PORTB |= 0x80; }
	
	output = 0x00;
}

void released() {
	temp = PINC;
	while (temp == temp2) {
		temp = PINC;
	}
}

void combine() {
	if (flag == 1) {
		
		return;
	}
		
	
}

void colFound() {
	released();
	passblink();
	
	if (flag == 0) { output = *(table+temp2); return; }
		
	if (flag == 1) { output = *(table+temp2) * 16; return; }
		
	if (flag == 2) { output += *(table+temp2); }
}

void ReadKP() {
	for (uint8_t j=0; j<4; j++) {
		temp = cols[j];
		PORTC = temp;
		_delay_ms(50);
		temp2 = PINC;
		if (temp != temp2) { colFound(); return; }
		
		if (j == 3) { j = -1; }
	}
}


void ReadTwo() {
	output = 0x00;
	flag = 1;
	ReadKP();
	flag = 2;
	_delay_ms(50);
	ReadKP();
}

void passcodeEntry() {
	for (uint8_t i=0; i<3; i++) {
		
		ReadTwo();
		passcodeInput[i] = output;
	}
	flag = 0;
}

void display() {
	PORTB = output;
	_delay_ms(1000);
}

int main(void)
{	
	DDRB = 0xFF;	// all pins output
	DDRC = 0xF0;	// first 4 bits output and last 4 bits input
	PORTC = 0x0F;    // setting pull up resistors for rows
	
	temp = colIdle;
	PORTC = temp;		// setting columns to idle
	
	temp = PINC;
	PORTB = 0x9F;   // armed
	
	while (1) {
		flag = 0;
		ReadKP();
		_delay_ms(50);
		
		if (output == 15) {
			PORTB |= 0x20;
			
			passcodeEntry();
			
			passcodeVerification();
		}
	}
	
	while (1);
}

