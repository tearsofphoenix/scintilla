/******************************************************************************
* Copyright (C) 2009 Zhang Lei.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
******************************************************************************/

#include <assert.h>
#include "Protocol.h"



int SendBreak(SOCKET s, const char * file, int line)
{
    LRDClientSocketBuffer sb;

    LRDClientSocketBufferInit(&sb, s);
    LRDClientSocketBufferAppendFormat(&sb, "BR\n%s\n%d\n\n", file, line);
    LRDClientSocketBufferAppend(&sb, "", 1); //Add the End-of-flow(EOF)
    return LRDClientSocketBufferSend(&sb);
}

int SendQuit(SOCKET s)
{
    return LRDSocketSendData(s, "QT\n\n", sizeof("QT\n\n")); //Including the EOF
}

int SendErr(SOCKET s, const char * fmt, ...)
{
    LRDClientSocketBuffer sb;
    va_list ap;

    LRDClientSocketBufferInit(&sb, s);
    LRDClientSocketBufferAppend(&sb, "ER\n", sizeof("ER\n") - 1);
    va_start(ap, fmt);
    LRDClientSocketBufferAppendArguments(&sb, fmt, ap);
    va_end(ap);
    LRDClientSocketBufferAppend(&sb, "\n", sizeof("\n")); //Include the End-of-flow(EOF)
    return LRDClientSocketBufferSend(&sb);
}

int SendOK(SOCKET s, Writer writer, void * writerData)
{
    LRDClientSocketBuffer sb;
    int rc = 0;

    LRDClientSocketBufferInit(&sb, s);
    LRDClientSocketBufferAppend(&sb, "OK\n", sizeof("OK\n") - 1);
    if (writer)
        while ((rc = writer(writerData, &sb)) == 1);
    LRDClientSocketBufferAppend(&sb, "\n", sizeof("\n")); //Include the End-of-flow(EOF)
    LRDClientSocketBufferSend(&sb);
    return (rc == 0 && !sb.ioerr) ? 0 : (rc < 0 ? rc : -1);
}

int RecvCmd(SOCKET s, char * buf, int len)
{
    char * p = buf;
    int avail = len;
    int received = 0;

    while (avail > 0)
    {
        ssize_t l = recv(s, p, avail, 0);
        if (l == SOCKET_ERROR)
            return -1;

        received += l;
        if (p[l - 1] == 0)
            return received - 1; //Return payload length, excluding the EOF character.

        p += l;
        avail -= l;
    }

    return -2;  //Too long
}

