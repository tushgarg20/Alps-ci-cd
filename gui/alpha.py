import tkinter as tk                    
from tkinter import ttk, filedialog
import tkinter.scrolledtext as tkscrolled

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
def add_logger_text(obj, menu, text):
    obj.config(state='normal')
    obj.insert('insert', menu,'menu')
    obj.insert('insert', text, 'option')
    obj.insert('insert', '\n')
    obj.config(state='disabled')

def add_text(obj, text):
    obj.config(state='normal')
    obj.delete(0,'end')
    obj.insert('insert', text)
    obj.config(state='disabled')

def del_text(obj):
    obj.config(state='normal')
    obj.delete(0, 'end')

def browse_input_dir():
    global input_dir_path
    input_dir_path = tk.StringVar()
    filename = filedialog.askdirectory()
    add_text(input_dir_path_entry, filename)
    input_dir_path.set(filename)
    if(filename):
        add_logger_text(logger, 'Input Dir : ', filename)

def browse_output_dir():
    global output_dir_path
    output_dir_path = tk.StringVar()
    filename = filedialog.askdirectory()
    add_text(output_dir_path_entry, filename)
    output_dir_path.set(filename)
    if(filename):
        add_logger_text(logger, 'Output Dir : ', filename)

def browse_alps_dir():
    global alps_dir_path
    alps_dir_path = tk.StringVar()
    filename = filedialog.askdirectory()
    add_text(alps_dir_path_entry, filename)
    alps_dir_path.set(filename)
    if(filename):
        add_logger_text(logger, 'ALPS Dir : ', filename)

def run_alps():
    pass
    #Check all the variables and call teh run_alps.pl script

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
            add_logger_text(logger, self.name, self.variable.get())
            
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
    'Frame Level + Workload Level           ',
    'Frame Level',
    'Workload Level'
]

input_mode_list = [
    'GSIM output directory                          ',
    'Dir with .stat.gz files' #Search for the weights.csv file in this dir or the parent dir
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
    'none',
    'cam',
    'emu'
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

mode_menu = dropMenu("Config : ", tab1, config_list, row_num)
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
row_num +=1

# ALPS Directory
label_output_dir = tk.Label(tab1, text = "ALPS Directory : ").grid(row = row_num, column = 0, sticky = 'E', pady=5)
alps_dir_path_entry = tk.Entry(tab1, width=40)
alps_dir_path_entry.config(state = 'disabled')
alps_dir_path_entry.grid(row=row_num, column=1, sticky='W')
alps_dir_but = tk.Button(tab1, text="Browse", command=browse_alps_dir)
alps_dir_but.grid(row=row_num, column=3)
row_num +=3

# Run ALPS
run_alps_but = tk.Button(tab1, text="RUN", command=run_alps)
run_alps_but.grid(row=row_num, columnspan = 3)

# Logger
logger = tkscrolled.ScrolledText(bottomFrame, state='disabled')
logger.tag_config('menu', foreground='purple')  
logger.pack(fill= 'x')

# **** Tab 2 **** #

# **** Tab 3 **** #

# **** BottomFrame **** #

# To display the window until you manually close it
root.mainloop()