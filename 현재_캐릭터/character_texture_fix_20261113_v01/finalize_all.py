from pathlib import Path
import runpy
out=Path(__file__).resolve().parent
runpy.run_path(str(out/'finish_native.py'),run_name='__main__')
runpy.run_path(str(out/'export_and_verify.py'),run_name='__main__')
