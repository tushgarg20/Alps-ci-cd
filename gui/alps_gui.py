import tkinter as tk                    
from tkinter import ttk, filedialog
import tkinter.scrolledtext as tkscrolled
import subprocess

root = tk.Tk()                           # Create instance      
root.title("ALPS_GUI 1.0")                       # Add a title 

#style = ttk.Style()
#style.theme_create( "MyStyle", parent="alt", settings={
#        "TNotebook": {"configure": {"tabmargins": [2, 5, 2, 0] } },
#        "TNotebook.Tab": {"configure": {"padding": [5, 2, 5, 2]}}})
#style.theme_use("MyStyle")

#Divide the root into two frames

#TopFrame - where all the tabs are present
topFrame = tk.Frame(root).pack()

#BottomFrame - where the command window is present
bottomFrame = tk.Frame(root, bd=2, relief='sunken').pack(fill = 'both', side = 'bottom')

# **** Top Frame **** #
tabControl = ttk.Notebook(topFrame, width=400, height=400)          

tab1 = ttk.Frame(tabControl)      
tab2 = ttk.Frame(tabControl) 
tab3 = ttk.Frame(tabControl)

tabControl.add(tab1, text='Run')        
tabControl.add(tab2, text='Post Process')
tabControl.add(tab3, text='Config Analysis')
tabControl.pack(expand=True, fill="both")  

# **** Tab 1 **** #
def log_tag_text(text, tag):
    logger.config(state='normal')
    logger.insert('insert', text, tag)
    logger.insert('insert', '\n')
    logger.config(state='disabled')

def log_menu_text(menu, text):
    logger.config(state='normal')
    logger.insert('insert', menu, 'menu')
    logger.insert('insert', text, 'option')
    logger.insert('insert', '\n')
    logger.config(state='disabled')

def add_text(obj, text):
    obj.config(state='normal')
    obj.delete(0,'end')
    obj.insert('insert', text)
    obj.config(state='disabled')

def del_text():
    logger.config(state='normal')
    logger.delete(0, 'end')

input_dir_path = tk.StringVar()
def browse_input_dir():
    filename = filedialog.askdirectory()
    add_text(input_dir_path_entry, filename)
    input_dir_path.set(filename)
    if(filename):
        log_menu_text('Input Dir : ', filename)

output_dir_path = tk.StringVar()
def browse_output_dir():
    filename = filedialog.askdirectory()
    add_text(output_dir_path_entry, filename)
    output_dir_path.set(filename)
    if(filename):
        log_menu_text('Output Dir : ', filename)


alps_dir_path = tk.StringVar()
def browse_alps_dir():
    filename = filedialog.askdirectory()
    add_text(alps_dir_path_entry, filename)
    alps_dir_path.set(filename)
    if(filename):
        log_menu_text('ALPS Dir : ', filename)


def run_alps():
    #Check all the variables and call the run_alps.pl script
    #print the command to the logger
    ###########################################
    #   UnComment this section for production #
    ###########################################

    if not input_dir_path.get():
        log_tag_text('Please select the Input Dir', 'error')
        return

    if not output_dir_path.get():
        log_tag_text('Please select the Output Dir', 'error')
        return

    if not alps_dir_path.get():
        log_tag_text('Please select the ALPS Dir', 'error')
        return

    if nb_menu.variable.get() == 'Yes':

        if nb_pool_text.get() == '':
            log_tag_text('Please enter the Net-Batch pool', 'error')
            return

        if nb_qslot_text.get() == '':
            log_tag_text('Please enter the Net-Batch qslot', 'error')
            return

    ##############################################
    #All the parameters are given - so run ALPS
    log_tag_text('******************************************', 'info')
    log_tag_text('Running ALPS with the following parameters', 'success')
    log_tag_text('******************************************', 'info')
    #Output_mode
    log_menu_text('Output Mode : ', output_mode_menu.variable.get())
    #Input_mode
    log_menu_text('Input Mode : ', input_mode_menu.variable.get())
    #Input_dir
    log_menu_text('Input Dir : ', input_dir_path.get())
    #Architecture
    log_menu_text('Architecture : ', arch_menu.variable.get())
    #Config
    log_menu_text('Config : ', config_menu.variable.get())
    #Net-batch
    log_menu_text('Net-batch : ', nb_menu.variable.get())
    
    if nb_menu.variable.get() == 'Yes':
        #Net-batch pool
        log_menu_text('Net Batch pool : ', nb_pool_text.get())
        #Net-batch qslot
        log_menu_text('Net Batch qslot : ', nb_qslot_text.get())

    #Output_dir
    log_menu_text('Output Dir : ', output_dir_path.get())
    #ALPS_dir
    log_menu_text('ALPS Dir : ', alps_dir_path.get())
    log_tag_text('******************************************', 'info')
    #########################################################
    #Running ALPS

    combined_ls = ' '
    #Execute the tracelist command
    ls_command = ['ls', '*.stat.gz ', '>', 'tracelist']
    log_menu_text('Executing the command in the Input dir: ', combined_ls.join(ls_command))
    ls_process = subprocess.Popen(combined_ls.join(ls_command), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,  cwd=input_dir_path.get() )
    stdout, stderr = ls_process.communicate()
    if stdout:
        log_tag_text('Output : ', 'success')
        log_tag_text(stdout, 'info')
        log_tag_text('******************', 'success')
    if stderr:
        log_tag_text('Error : ', 'error')
        log_tag_text(stderr, 'error')
        log_tag_text('******************', 'error')

    #Execute the runall-alps command
    combined_runall = ' '
    if nb_menu.variable.get() == 'Yes':
        runall_command = ["perl", alps_dir_path.get() + '/runall_alps.pl', "-i", "tracelist", "-o", ".", "-s", alps_dir_path.get(), "-a",  arch_menu.variable.get(), "-p",  nb_pool_text.get(), "-q", nb_qslot_text.get(), "--" + arch_menu.variable.get(), "--" + config_menu.variable.get(), "-m", config_menu.variable.get() ]
        log_menu_text('Executing the command in the Input dir: ', combined_runall.join(runall_command))
        runall_process = subprocess.Popen(combined_runall.join(runall_command), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=input_dir_path.get())
    else:
        runall_command = ["perl", alps_dir_path.get() + '/runall_alps.pl', "-i", "tracelist", "-o", ".", "-s", alps_dir_path.get(), "-a",  arch_menu.variable.get(), "--" + arch_menu.variable.get(), "--" + config_menu.variable.get(), "-m", config_menu.variable.get(), "-runLocal"]
        log_menu_text('Executing the command in the Input dir: ', combined_runall.join(runall_command))
        runall_process = subprocess.Popen(combined_runall.join(runall_command), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=input_dir_path.get())

    stdout, stderr = runall_process.communicate()
    if stdout:
        log_tag_text('Output : ', 'success')
        log_tag_text(stdout, 'info')
        log_tag_text('******************', 'success')
    if stderr:
        log_tag_text('Error : ', 'error')
        log_tag_text(stderr, 'error')
        log_tag_text('******************', 'error')

    ########################################################



#TODO - P0: Be able to run a script and output the stdout to the terminal in the GUI
    #Call a script that print to the stdout
#TODO - P0: Be able to read the netbatch file and figure out the status
#TODO - P1: Add a reset all button to remove all the inputs


class dropMenu:
    def __init__(self, name, tab, options, numRow):
        self.options = options
        self.tab = tab
        self.name = name
        self.label = tk.Label(tab, text = name).grid(row = numRow, column = 0, sticky = 'E', pady=5)
        self.variable = tk.StringVar(tab)
        self.variable.set(self.options[0])
        self.numRow = numRow

        self.opt = tk.OptionMenu(tab, self.variable, *self.options)
        self.opt.config(width = 35)
        self.opt.grid(row = numRow, column = 1, sticky = 'W')

        self.labelTest = tk.Label(tab, text = "", fg = "red")
        self.labelTest.grid(row = numRow, column = 2)
        
        def callback(*args):
            log_menu_text(self.name, self.variable.get())
            
            # Callback for Net batch
            if self.name.find('Net Batch') != -1:
                if self.variable.get() == 'Yes':
                    del_text(nb_pool_text)
                    del_text(nb_qslot_text)
                else:
                    add_text(nb_pool_text, 'Not Applicable')
                    add_text(nb_qslot_text, 'Not Applicable')

        self.variable.trace("w", callback)

output_mode_list = [
    'Frame Level',
    'Frame Level + Workload Level           ',
    'Workload Level'
]

input_mode_list = [
    'Dir with .stat.gz files', #Search for the weights.csv file in this dir or the parent dir
    'GSIM output directory                          '
]

# TODO : Update this list and figure out the order
arch_list = [
    'tgldg',
    'gen12dg',
    'tgl',
    'icl'
]

# TODO : Update this list 
config_list = [
    'emu',
    'none',
    'cam'
]

nb_list = [
    'Yes',
    'No'
]

row_num = 0

output_mode_menu = dropMenu("Output Mode : ", tab1, output_mode_list, row_num)
row_num += 1

input_mode_menu = dropMenu("Input Mode : ", tab1, input_mode_list, row_num)
row_num += 1

# Input Directory
label_input_dir = tk.Label(tab1, text = "Input Directory : ").grid(row = row_num, column = 0, sticky = 'E', pady=5)
input_dir_path_entry = tk.Entry(tab1, width=40)
input_dir_path_entry.config(state = 'disabled')
input_dir_path_entry.grid(row=row_num, column=1, sticky='W')
input_dir_but = tk.Button(tab1, text="Browse", command=browse_input_dir)
input_dir_but.grid(row=row_num, column=3)
row_num += 1

arch_menu = dropMenu("Architecture : ", tab1, arch_list, row_num)
row_num += 1

config_menu = dropMenu("Config : ", tab1, config_list, row_num)
row_num += 1

nb_menu = dropMenu("Net Batch : ", tab1, nb_list, row_num)
row_num += 1

# Net Batch pool
label_nb_pool = tk.Label(tab1, text = "Net Batch pool : ").grid(row = row_num, column = 0, sticky = 'E', pady=5)
nb_pool_text = tk.Entry(tab1, width=40)
nb_pool_text.config(disabledbackground = "#eff0f1")
nb_pool_text.grid(row = row_num, column = 1, sticky = 'W')
row_num += 1

# Net Batch qslot
label_nb_qslot = tk.Label(tab1, text = "Net Batch qslot : ").grid(row = row_num, column = 0, sticky = 'E', pady=5)
nb_qslot_text = tk.Entry(tab1, width=40, disabledbackground = "#eff0f1")
nb_qslot_text.config(disabledbackground = "#eff0f1")
nb_qslot_text.grid(row = row_num, column = 1, sticky = 'W')
row_num += 1

# Output Directory
label_output_dir = tk.Label(tab1, text = "Output Directory : ").grid(row = row_num, column = 0, sticky = 'E', pady=5)
output_dir_path_entry = tk.Entry(tab1, width=40)
output_dir_path_entry.config(state = 'disabled')
output_dir_path_entry.grid(row=row_num, column=1, sticky='W')
output_dir_but = tk.Button(tab1, text="Browse", command=browse_output_dir)
output_dir_but.grid(row=row_num, column=3)
row_num += 1

# ALPS Directory
label_output_dir = tk.Label(tab1, text = "ALPS Directory : ").grid(row = row_num, column = 0, sticky = 'E', pady=5)
alps_dir_path_entry = tk.Entry(tab1, width=40)
alps_dir_path_entry.config(state = 'disabled')
alps_dir_path_entry.grid(row=row_num, column=1, sticky='W')
alps_dir_but = tk.Button(tab1, text="Browse", command=browse_alps_dir)
alps_dir_but.grid(row=row_num, column=3)
row_num +=3

# Run ALPS
run_alps_btn = tk.Button(tab1, text="RUN", command=run_alps)
run_alps_btn.grid(row=row_num, columnspan = 3)

# Logger
logger = tkscrolled.ScrolledText(bottomFrame, state='disabled')
logger.tag_config('menu', foreground='purple')
logger.tag_config('option', foreground='blue')
logger.tag_config('error', foreground='red') 
logger.tag_config('info', foreground='violet')
logger.tag_config('success', foreground='green')
logger.pack(fill= 'x')

# **** Tab 2 **** #

# **** Tab 3 **** #

# **** BottomFrame **** #

# To display the window until you manually close it
root.mainloop()