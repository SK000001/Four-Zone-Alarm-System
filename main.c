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
					
uint8_t passcode[] = {1, 2, 3, 4, 5, 6};
uint8_t passcodeInput[6];

void triggerSiren() {
	PORTB |= 0x20;								// turn on the siren LED ( PORTB || 0x20 )
}

void triggerStrobe() {
	for (uint8_t i=0; i<5; i++) {
		PORTB ^= (1<<3);						// toggle strobe LED on and off 5 times
		_delay_ms(500);							// 5Hz delay
	}
}

void triggerZone(uint8_t zone) {
	PORTB |= zone;								// turn on the triggered Zone LED
	triggerSiren();								// turn on the siren LED ( PORTB || 0x20 )
	triggerStrobe();							// blink strobe light at 5Hz for 5 times
}

void errorBlink() {
	uint8_t t = PINB;
	
	for (uint8_t i=0; i<2; i++) {
		PORTB = 0x00;
		_delay_ms(1000);
		PORTB = 0xFF;
		_delay_ms(1000);
	}
	
	PORTB = t;
}

void passblink() {
	PORTB &= 0x0F;
	PORTB |= output;
	_delay_ms(50);
}

void released() {
	temp = PINC;
	while (temp == temp2) {
		temp = PINC;
	}
}

void colFound() {
	released();
	
	output = *(table+temp2);
	PORTB |= output;
}

void ReadKP() {
	for (uint8_t i=0; i<4; i++) {
		temp = cols[i];
		PORTC = temp;
		_delay_ms(50);
		temp2 = PINC;
		if (temp != temp2) { colFound(); return; }
		
		if (i == 3) { i = -1; }
	}
}

void enterNewPasscode() {
	for (uint8_t i=0; i < 6; i++) {						// loop 6 times to read 6 digits of passcode
		ReadKP();
		
		if (output>9) { errorBlink(); return; }			// if in disarmed state, and any zone keys or */# is pressed
			
		passcodeInput[i] = output;
	}
	
	for (uint8_t i=0; i < 6; i++) {
		passcode[i] = passcodeInput[i];
	}
}

void passcodeVerification(uint8_t stateFlg) {
	for (uint8_t i=0; i<6; i++) {
		if (passcode[i] != passcodeInput[i]) {
			errorBlink();
			return;
		}
	}
	
	if (stateFlg == 1) {
		output = 0x40;									// turn on the armed state LED
		PORTB = output;									// armed state
		return;
	}
	
	output = 0x80;										// turn on the disarmed state LED
	PORTB = output;										// disarmed state
}

void passcodeEntry(uint8_t state) {
	for (uint8_t i=0; i < 6; i++) {						// loop 6 times to read 6 digits of passcode
		ReadKP();
		
		if (state == 1) {								// if in armed state, check if any zone keys are pressed ( A, B, C, D )
			switch (output) {
				case 10:
					triggerZone(0xB0);
					return;
				case 11:
					triggerZone(0x90);
					return;
				case 12:
					triggerZone(0x80);
					return;
				case 13:
					triggerZone(0x50);
					return;		
			}
		}
		
		if (output == 15) {								// if # is pressed change passcode
			enterNewPasscode();
			return;
		}
		
		passcodeInput[i] = output;
	}
}

int main(void)
{	
	DDRB = 0xFF;	// all pins output
	DDRC = 0xF0;	// first 4 bits output and last 4 bits input
	PORTC = 0x0F;    // setting pull up resistors for rows
	
	temp = colIdle;
	PORTC = temp;		// setting columns to idle
	
	temp = PINC;
	output = 0x80;
	PORTB = output;   // disarmed state
	
	while (1) {
		output = PINB;
		
		switch (output) {
			case 0x80:							// is in disarmed state
				passcodeEntry(0);				// ask to enter passcode and store it in passcodeEntry Array
				passcodeVerification(1);		// verify passcode with change state flag of armed state
				break;
				
			case 0x40:							// is in armed state
				passcodeEntry(1);				// ask to enter passcode and store it in passcodeEntry Array
				passcodeVerification(0);		// verify passcode with change state flag of disarmed state
				break;	
		}
	}
	
	while (1);
}
