f = open("./test.txt","w",newline='')
for i in range(256):
    l = hex(i % 128)
    f.write(l.strip("0x"))
    f.write('\n')
f.close()
