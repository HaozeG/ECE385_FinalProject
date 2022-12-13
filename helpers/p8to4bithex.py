# Generate sprite table
import numpy as np
new = []

f = open("./original.txt", "r", encoding='utf-8')
s = f.readlines()
for f1 in s:
    line = ""
    i = 0
    for c in f1:
        line += c
        i += 1
        if (i == 8):
            new.append(line.strip())
            i = 0
            line = ""
f.close()

# sort
sorted = [['' for j in range(8)] for i in range(128)]
# sorted = np.empty([128,8])
x = 0
y = 0
i = 0
for l in new:
    if (i == 1024): break
    x = i % 16
    print("i =",i)
    print("x =",x)
    y = (i // (16 * 8))
    sorted[int(x + y*16)][(i // 16) % 8] = l
    i += 1
print(sorted[41])


f = open("./test1.txt","w",newline='')
for l in sorted:
    for l1 in l:
        f.write(l1)
        # f.write('\n')
f.close()


new = []

f = open("./test1.txt", "r", encoding='utf-8')
s = f.readlines()
for f1 in s:
    i = 0
    for c in f1:
        i += 1
        new.append(c)
f.close()
print(len(new))

f = open("./test1.txt","w",newline='')
for l in new:
    f.write(l.strip())
    f.write('\n')
f.close()
