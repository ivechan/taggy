import vim
import subprocess as sp
import jsa:on
import time

def update_taglist_for_cb():
    """
    :returns: TODO

    """
    begin = time.time()
    cb = vim.current.buffer
    filename = cb.name
    if filename:
        args = ['ctags', '--fields=*', '-f -', '--extras=+q', '--output-format=json', filename]
        with sp.Popen(args, stdout=sp.PIPE) as p:
            output, err = p.communicate(timeout=2)
            output = str(output, 'utf-8')
            lines = output.splitlines()
            lines_as_dict = [json.loads(x) for x in lines]

            cb.vars['taggylist'] = vim.List(lines_as_dict)
    end = time.time()
    print('time elapsed:{}s.'.format(end - begin))
