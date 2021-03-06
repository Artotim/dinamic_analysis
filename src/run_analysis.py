from src.color_log import log
import os
from signal import SIGTERM
import subprocess
from time import sleep


def start_frame_analysis(out, name, vmd, chimera, init, last, cci, program_path, pdb_path):
    """Run vmd for frame analysis"""

    log('info', 'Starting frame analysis.')

    log_file = out + 'logs/' + name + '_frame.log'
    err_file = out + 'logs/' + name + '_frame.err'
    vmd_file = out + 'temp_frame_analysis.tcl'

    log('info', 'Logging frame analysis info to ' + log_file + '.')

    cmd = [vmd, '-e', vmd_file]

    try:
        with open(log_file, 'w') as log_f, open(err_file, "w") as err_f:
            process = subprocess.Popen(cmd, stdout=log_f, stderr=err_f, preexec_fn=os.setsid)

            if chimera:
                run_chimera(out, name, init, last, cci, program_path, pdb_path)

            while process.poll() is None:
                sleep(300)

    except (PermissionError, FileNotFoundError):
        log('error', 'VMD exe not found! Please specify path with -e.')
        return

    except KeyboardInterrupt:
        os.killpg(os.getpgid(process.pid), SIGTERM)
        raise

    log('info', 'Frame analysis done.')


def run_chimera(out, name, init, last, cci, program_path, pdb_path):
    """Run chimera for contact analysis"""

    log('info', 'Running chimera for contact analysis.')

    chimera_stats = prepare_chimera(out, name, init, last, cci, program_path, pdb_path)
    log('info', 'Logging chimera analysis info to ' + chimera_stats[1] + '.')

    try:
        with open(chimera_stats[1], 'w') as chimera_log, open(chimera_stats[2], "w") as chimera_err:
            process = subprocess.Popen(chimera_stats[0], stdout=chimera_log, stderr=chimera_err)
            while process.poll() is None:
                sleep(300)

    except (PermissionError, FileNotFoundError):
        log('error', 'Error running chimera.')
        return

    except KeyboardInterrupt:
        process.terminate()
        process.kill()
        raise

    log('info', 'Chimera analysis done.')


def prepare_chimera(out, name, init, last, cci, program_path, pdb_path):
    """Prepare arguments to run chimera"""

    from src.tcl_writer import write_get_chain

    get_chain = write_get_chain([], program_path, pdb_path)

    vmd_chain = subprocess.Popen('vmd', stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.STDOUT)
    grep_stdout = vmd_chain.communicate(input=str.encode(''.join(get_chain)))[0]
    main_chain = grep_stdout.decode().split('\n')[-6][0]
    peptide = grep_stdout.decode().split('\n')[-5][0]

    path = program_path + 'chimera/chimera_contacts.py'
    cmd = ['python', '-m', 'pychimera', path, out, str(init), str(last), str(cci), str(main_chain), str(peptide)]

    log_file = out + 'logs/' + name + '_chimera.log'
    err_file = out + 'logs/' + name + '_chimera.err'

    return cmd, log_file, err_file


def start_energies_analysis(out, name, vmd):
    """Run vmd for energy analysis"""

    log('info', 'Starting energies analysis.')

    log_file = out + 'logs/' + name + '_energies.log'
    err_file = out + 'logs/' + name + '_energies.err'
    vmd_file = out + 'temp_energies_analysis.tcl'

    log('info', 'Logging energies analysis info to ' + log_file + '.')

    cmd = [vmd, '-e', vmd_file]

    try:
        with open(log_file, 'w') as log_f, open(err_file, "w") as err_f:
            process = subprocess.Popen(cmd, stdout=log_f, stderr=err_f, preexec_fn=os.setsid)
            while process.poll() is None:
                sleep(300)

    except (PermissionError, FileNotFoundError):
        log('error', 'VMD exe not found! Please specify path with -e.')
        return

    except KeyboardInterrupt:
        os.killpg(os.getpgid(process.pid), SIGTERM)
        raise

    log('info', 'Frame analysis done.')


def start_score_analysis(out, name, program_path, init, final, sci):
    """Prepare models score analysis"""

    log('info', 'Starting score analysis.')
    
    log_file = out + 'logs/' + name + '_score.log'
    err_file = out + 'logs/' + name + '_score.err'

    log('info', 'Logging score analysis info to ' + log_file + '.')
    
    models = [F"{out}models/first_model.pdb"]
    count = init + sci

    while count < final:
        models.append(F"{out}score/score_model_{str(count)}.pdb")
        count += sci

    models.append(F"{out}models/last_model.pdb")

    for file_name in models:
        if os.path.isfile(file_name):
            run_score_clean(program_path, file_name, log_file, err_file)
            run_score_minimize(program_path, out, file_name, log_file, err_file)
        else:
            log('error', 'Score error. Missing file ' + file_name + '.')

    log('info', 'Score analysis done.')


def run_score_clean(program_path, model, log_file, err_file):
    """Run rosetta clean routine"""

    script_path = program_path + "rosetta/tools/protein_tools/scripts/clean_pdb.py"
    cmd = ['python', script_path, model, 'ignorechain']

    try:
        with open(log_file, 'a+') as log_f, open(err_file, "a+") as err_f:
            process = subprocess.Popen(cmd, stdout=log_f, stderr=err_f)
            while process.poll() is None:
                sleep(1)

    except (PermissionError, FileNotFoundError):
        log('error', 'Scoring error.')
        return


def run_score_minimize(program_path, out, model, log_file, err_file):
    """Run rosetta minimize score analysis"""

    score_path = out + "score/"
    model = model.replace(".pdb", "_ignorechain.pdb")
    bin_path = program_path + 'rosetta/main/source/bin/relax.static.linuxgccrelease'

    cmd = [bin_path, '-s', model, '-out:path:all', score_path, '-out:suffix',
           '_relaxed', '-nstruct', '1', '-relax:default_repeats', '5']

    try:
        with open(log_file, 'a+') as log_f, open(err_file, "a+") as err_f:
            process = subprocess.Popen(cmd, stdout=log_f, stderr=err_f)
            while process.poll() is None:
                sleep(300)

    except (PermissionError, FileNotFoundError):
        log('error', 'Scoring error.')
        return

    except KeyboardInterrupt:
        process.terminate()
        process.kill()
        raise
