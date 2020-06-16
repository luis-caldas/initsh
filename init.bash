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
PROJECT_SHELL_GIT_BRANCH="master"
PROJECT_VIM_NAME="vimino"
PROJECT_VIM_GIT_NAME="myvim"
PROJECT_VIM_GIT_BRANCH="ebf5d48ede7d2da5db93811029b783b955181237"


# Bashrc file path
BASHRC_FILE="${HOME}""/.bashrc"

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
        # Check if branch is given
        branch="master"
        [ -n "$3" ] && branch="$3"
        # Get the module name
        module_name=$(basename "${2}")
        # Verbose
        echo "Cloned ${module_name} successfully"
        # Checkout to branch
        (
            cd "$2" && \
            if git checkout "$branch" &> /dev/null; then
                echo "Changed ${module_name} to branch ${3}"
            else
                echo "Unable to change ${module_name} to ${3}"
                exit 1
            fi
        )
        # Fetch all the submodules as well
        ( 
            # Go to the project folder and clone submodules
            cd "${2}" && \
            if git submodule update --init --recursive &> /dev/null; then
                echo "Cloned ${module_name} submodules successfully"
            else
                echo "Unable to fetch ${module_name} submodule";
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
    run_q_git "${TOP_GIT_URL}/${PROJECT_SHELL_GIT_NAME}" "${output_folder}/${PROJECT_SHELL_NAME}" "${PROJECT_SHELL_GIT_BRANCH}"
    run_q_git "${TOP_GIT_URL}/${PROJECT_VIM_GIT_NAME}" "${output_folder}/${PROJECT_VIM_NAME}" "${PROJECT_VIM_GIT_BRANCH}"

    # Create the start file that will start the shell and alias the vim config
    start_file_path="${output_folder}/start.bash"
    tmux_start_file_path="${output_folder}/tmux.bash"

    # Add the tmux starter script
    tmux_session_name="sherino"
    cat <<-EOF > "$tmux_start_file_path"
		#!/usr/bin/env bash
		bash "${output_folder}/${PROJECT_SHELL_NAME}/tmux/start.bash" new-session -d -s "$tmux_session_name"
		tmux send-keys -t "$tmux_session_name" "source \"$start_file_path\"" Enter
		tmux attach -t "$tmux_session_name"
	EOF
    # Fix permissions
    chmod 755 "$tmux_start_file_path"

    # Add the start script to it
    cat <<-EOF > "$start_file_path"
		#!/usr/bin/env bash
		alias vim='vim -u "${output_folder}/${PROJECT_VIM_NAME}/vimrc.vim"'
		source ${output_folder}/${PROJECT_SHELL_NAME}/shell/shell.bash
		alias neotmux='bash "${tmux_start_file_path}"'
	EOF
    # Fix permissions
    chmod 755 "$start_file_path"

    # Add alias to bashrc if persistent installation
    if [ "$add_alias_bashrc" -eq 1 ]; then
        alias_line="alias ${PROGRAM_ALIAS}='bash --init-file \"${start_file_path}\"'"
        if ! grep -Fxq "$alias_line" "$BASHRC_FILE" &> /dev/null; then
            echo "$alias_line" >> "$BASHRC_FILE"
        fi
    fi

    # Start it
    bash --init-file "$start_file_path"

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
