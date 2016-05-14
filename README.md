# securecrt-scripts
Short, handy scripts for network engineers using VanDyke's SecureCRT

## RunAndCompareCommands - run some show commands before and after you apply major changes to a network device, compare results

In short, the main idea of this script is to collect an output from some 'show' commands, which you run before, and after you apply major changes to your network device. Then, both files are compared using freeware tool ExamDiff. You can then not only compare running configs to verify if all planned commands were applied, but also status of protocols and relationship to other devices. So, you can make sure, your network works as expected, and you suddenly do not miss half of your routes because your filtering is wrong. What the script does is:

1. The script is run before you apply your planned changes:
 * Lets you choose device type, which defines commands to execute
 * Stops logging (if enabled) for current session (remembers old file)
 * Creates new file named <hostname>_<date>_before.txt
 * Writes output from show commands, specific to choosen device type
 * Recovers old logging file, so you can log the rest of your change process

2. The script is run after you finish the planned change:
 * Lets you choose device type (make sure you select the same type as before, so the same commands are executed)
 * Stops logging (if enabled) for current session (remembers old file)
 * Creates new file named <hostname>_<date>_after.txt
 * Writes output from show commands, specific to choosen device type
 * Recovers old logging file
 * Runs ExamDiff to compare _before and _after outputs

__Prerequisites__
 - ExamDiff tool: http://www.prestosoft.com/edp_examdiff.asp#download
