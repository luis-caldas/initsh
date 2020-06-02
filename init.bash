#!/usr/bin/env bash

# {{{ Global vars

# Name of the folder that will store the packages
FOLDER_NAME="bashellino"

# Path for folders to store the main folder
TMP_FOLDER="/tmp"
PERSISTENT_FOLDER="${HOME}/.config"

# Naming of the git project
TOP_GIT_URL="https://github.com/luis-caldas"
PROJECT_SHELL_NAME="shellino"
PROJECT_SHELL_GIT_NAME="myshell"
PROJECT_VIM_NAME="vimino"
PROJECT_VIM_GIT_NAME="myvim"

# Bashrc file path
BASHRC_FILE="${HOME}""/.bashrci"

# Alias in which to call the new shell
PROGRAM_ALIAS="$FOLDER_NAME"

# Binaries needed for the programs
NEEDED_BINARIES=(git vim bash tmux envsubst bc)

# }}}

# {{{ Functions

# Iterates all the needed binaries and check if they exist
check_binaries() {
    # Init the list for the binaries that wont be found
    not_found_list=()

    # Iterate the binaries
    for each_bin in "${NEEDED_BINARIES[@]}"; do
        if ! [ -x "$(command -v "$each_bin")" ]; then
            not_found_list+=("$each_bin")
        fi
    done

    # Check if there are bins not found
    if ! [ ${#not_found_list[@]} -eq 0 ]; then
        echo "You need the following programs for this script to run:"
        for each_not_found in "${not_found_list[@]}"; do
            printf "\t%s\n" "$each_not_found"
        done
        exit 1
    fi

}

# Runs git quietly and show simple error messages
run_q_git() {
    if git clone "$1" "$2" &> /dev/null; then
        # Get the module name
        module_name=$(basename "${2}")
        # Verbose
        echo "Cloned ${module_name} successfully"
        # Fetch all the submodules as well
        ( 
            # Go to the project folder and clone submodules
            cd "${2}" && \
            if git submodule update --init --recursive &> /dev/null; then
                echo "Cloned ${module_name} submodules successfully"
            else
                echo "Unable to fetch ${1} submodule"; 
                exit 1;
            fi
        )
        # Delete .git folder
        rm -rf "${2}/.git"
    else 
        echo "Unable to fetch ${1}"
        exit 1
    fi
}

# }}}

# {{{ Main

usage() {
    echo "Usage: $0 {p|persistent}"
}

main() {
   
    # Check for needed binaries
    check_binaries

    # Initialize some needed variables
    output_folder="${TMP_FOLDER}/${FOLDER_NAME}"
    add_alias_bashrc=0

    # Check if this installation is permanent
    if [ "$1" -eq 1 ]; then
        output_folder="${PERSISTENT_FOLDER}/${FOLDER_NAME}"
        add_alias_bashrc=1
        echo "Persistent installation was selected"
    else
        echo "Temporary installation was selected"
    fi

    # Delete old versions of the project
    if [ -d "$output_folder" ]; then
        echo "Found old installation folder, the folder will be deleted"
        rm -rf "$output_folder"
    fi

    # Create the project folder itself
    mkdir -p "${output_folder}"

    # Clone all the needed repositories
    run_q_git "${TOP_GIT_URL}/${PROJECT_SHELL_GIT_NAME}" "${output_folder}/${PROJECT_SHELL_NAME}" 
    run_q_git "${TOP_GIT_URL}/${PROJECT_VIM_GIT_NAME}" "${output_folder}/${PROJECT_VIM_NAME}" 

    # Create the start file that will start the shell and alias the vim config
    start_file_path="${output_folder}/start.bash"
   
    # Add the start script to it
    cat <<-EOF > "$start_file_path"
		#!/usr/bin/env bash
		export VIMINIT=${output_folder}/${PROJECT_VIM_NAME}/vimrc.vim
		bash ${output_folder}/${PROJECT_SHELL_NAME}/shell/shell.bash
	EOF
    # Fix permissions
    chmod 755 "$start_file_path"

    # Add alias to bashrc if persistent installation
    if [ "$add_alias_bashrc" -eq 1 ]; then
        alias_line="alias ${PROGRAM_ALIAS}=${start_file_path}"
        if ! grep -Fxq "$alias_line" "$BASHRC_FILE" &> /dev/null; then
            echo "$alias_line" >> "$BASHRC_FILE"
        fi
    fi

    # Start it
    exec "$start_file_path"

}

case "$1" in
    p|persistent)
        main 1
        ;;
    -h|--help)
        usage
        ;;
    *)
        main 0
        ;;
esac

# }}}
