Group Members: Alex Litchfield and Alex Rougebec

List of features and bugs

1. BUG: The code currently does not have proper functionality for the distributive method. 
2. FEATURE: The directory service Actor can recieve the following messages:
    a. Create -> The directory service calls upon the first file server that was retrieved from the hash function to store the file.
                It will then check if the file server is active, and proceed to place that file in subsequent fileServers in the line until the R parameter has decremented to zero.
    b. Get -> The directory service calls upon the first file server that was retrieved from the hash function to get the file from.
                If the server is active and does not have the file, it will return an error and error file. If the server is inactive, it will forward the request to the next server until it either decrements R to zero OR finds an active server to pull from.
    c. Quit -> The directory services will call upon each file server to terminate, and then terminate itself and the program.
    d. Deactivate -> The directory service will call upon the provided file server and have it's status switched to inactive,
                thereby only being able to handle forward requests from now on.
    e. startDirService -> The directory service actor once created will begin to create the requested amount of fileServers provided
                by the message. All services are by default active and empty.
    
3. FEATURE: Each FileServer is connected in a ring, allowing them to send data around to each other in a line fashion as long as the
            R parameter permits it.
