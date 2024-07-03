#!/bin/bash
#Since the  script requires root privileges to perform actions like creating users, 
#modifying permissions, and writing to system directories like /var/log, the script requires elavated permission

#The root user has a UID of 0
ROOT_UID=0     
if [ "$UID" -ne "$ROOT_UID" ]; then
    echo"***** You must be the root user to run this script!*****"
    exit
fi

log_dir="/var/log"
log_file="$log_dir/user_management.log"

secure_dir="/var/secure"
password_file="$secure_dir/user_passwords.csv"

# Function to create directories if they don't exist and assigning the necessary permission
create_directories() {
    # Create log directory if it doesn't exist
    if [ ! -d "$log_dir" ]; then
        sudo mkdir -p "$log_dir"
        sudo chmod 755 "$log_dir"
        sudo chown root:root "$log_dir"
    fi

    # Create secure directory if it doesn't exist
    if [ ! -d "$secure_dir" ]; then
        sudo mkdir -p "$secure_dir"
        sudo chmod 700 "$secure_dir"
        sudo chown root:root "$secure_dir"
    fi
}

# Function to log messages with timestamp
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp $1" >> "$log_file"
}

# Function to generate a random password


generate_password() {
    # Set the desired length of the password
    local password_length=12 
    # Generate the password
    local password="$(openssl rand -base64 12 | tr -d '/+' | head -c $password_length)"  
    # Output the generated password
    echo "$password"  
}



# Function to check if file is valid
process_user_file() {
    local filename="$1"
    # Check if the file exists and is readable
    if [ ! -f "$filename" ]; then
        echo "****Error: File '$filename' not found or is not readable.****"
	log  "Error: File '$filename' not found or is not readable."
        return 1
    fi

    # Process each line in the file
    while IFS=';' read -r username groups; do
        if [[ ! -z "$username" && ! -z "$groups" ]]; then
            create_user "$username" "$groups"
        else
            echo "****Invalid format in line: '$username;$groups'****" 
            log "Invalid format in line: '$username;$groups'"
        fi
    done < "$filename"
}

# Function to create a user and set up their home directory
create_user() {
    local username="$1"
    local groups="$2"

    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "***** User '$username' already exist. *****"
        log "User '$username' already exists."
    else
        # Generate random password
        local password=$(generate_password)
        # Create user with home directory
        sudo useradd -m -p "$(openssl passwd -6 "$password")" "$username"
        # Making the user the owner of the directory
        sudo chown "$username:$username" "/home/$username"


        # Set initial group (same as username)
	    # Automatically, once a user is created a group with the same name as the user is created 
	    # Check if group already exists
        if ! grep -q "^$username:" /etc/group; then
           sudo groupadd "$username"
            #Adding the user to the group which is the primary group
            sudo usermod -aG group_name "$username"
            #change the primary group of a user
            sudo usermod -g "$username" "$username"
        fi
        echo "****User '$username' created successfully.****"
        # Log and store password securely
        echo "Username: $username, Password: $password" >> "$password_file"
	l   log "Password for '$username' securely stored in $password_file."
        echo "****Password for '$username' securely stored in $password_file.****"
        # Add user to additional groups
        add_to_groups "$username" "$groups"
    fi
}

# Function to add users to specified groups
add_to_groups() {
    local username="$1"
    local groups="$2"
    IFS=',' read -ra group_list <<< "$groups"
    # Split groups into an array using comma as delimiter
    for group in "${group_list[@]}"; do
        if grep -q "^$group:" /etc/group; then
            # If group exists add user to the group
            sudo usermod -aG "$group" "$username"
            log "User '$username' added to group '$group' successfully."
            echo "****User '$username' added to group '$group' successfully.****"
        else
            log "Group '$group' does not exist. Skipping addition of user '$username'."
            echo "****Group '$group' does not exist. Skipping addition of user '$username'.****"
        fi
    done
}

# Main execution starts here
create_directories
process_user_file "$1"
# Inform the user where to find the logs
echo "****Logs are available at: $log_file.****"
