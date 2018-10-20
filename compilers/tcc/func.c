#include <inttypes.h>


uint32_t __stdcall handle_messages_and_return(uint32_t wndhandle, char *messages, uint32_t count, uint32_t(__stdcall *wndProc)(uint32_t wndhandle, uint32_t message, uint32_t wParam, uint32_t lParam), uint32_t result) {

    asm volatile("nop\nnop\nnop"::);

    while(count != 0) {
        uint32_t message = *((uint32_t*)messages);
        uint32_t wParam = *((uint32_t*)messages+1);
        uint32_t lParam = *((uint32_t*)messages+2);

        wndProc(wndhandle, message, wParam, lParam);

        count--;
        messages+=12;
    }

    return result;
    asm volatile("nop\nnop\nnop"::);
}

int main() {
    return 0;
}
