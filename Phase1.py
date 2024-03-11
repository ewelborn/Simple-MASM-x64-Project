x = [5, 7, 2, -3, 4, 15, 7, 8]
y = [1, 0, -1, 4, 5, 2, -3, 4]

def mean_array(arr, length):
    sum = 0
    
    # Loop through i=0 to i=length-1
    for i in range(length):
        sum = sum + arr[i]
        
    return sum / length
    
x_sum = mean_array(x, 8)
y_sum = mean_array(y, 8)

print(x_sum)
print(y_sum)