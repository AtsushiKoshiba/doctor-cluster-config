#!/usr/bin/env python3

import os
from contextlib import contextmanager
from typing import List, Dict, Tuple, IO, Iterator, Optional, Callable, Any, Union
from threading import Thread
import subprocess
import fcntl
import select
from contextlib import ExitStack


@contextmanager
def pipe() -> Iterator[Tuple[IO[str], IO[str]]]:
    (pipe_r, pipe_w) = os.pipe()
    read_end = os.fdopen(pipe_r, "r")
    write_end = os.fdopen(pipe_w, "w")

    try:
        fl = fcntl.fcntl(read_end, fcntl.F_GETFL)
        fcntl.fcntl(read_end, fcntl.F_SETFL, fl | os.O_NONBLOCK)

        yield (read_end, write_end)
    finally:
        read_end.close()
        write_end.close()


FILE = Union[None, int]


class DeployHost:
    def __init__(
        self,
        host: str,
        user: str = "root",
        port: int = 22,
        forward_agent: bool = False,
        command_prefix: Optional[str] = None,
        meta: Dict[str, Any] = {},
    ) -> None:
        self.host = host
        self.user = user
        self.port = port
        if command_prefix:
            self.command_prefix = command_prefix
        else:
            self.command_prefix = host
        self.forward_agent = forward_agent
        self.meta = meta

    def _prefix_output(
        self, print_fd: IO[str], stdout: Optional[IO[str]], stderr: Optional[IO[str]]
    ) -> Tuple[str, str]:
        rlist = [print_fd]
        if stdout is not None:
            rlist.append(stdout)

        if stderr is not None:
            rlist.append(stderr)

        print_buf = ""
        stdout_buf = ""
        stderr_buf = ""

        while len(rlist) != 0:
            r, _, _ = select.select(rlist, [], [])

            if print_fd in r:
                read = os.read(print_fd.fileno(), 4096)
                if len(read) == 0:
                    rlist.remove(print_fd)
                print_buf += read.decode("utf-8")
                if read == "" or "\n" in print_buf:
                    lines = print_buf.rstrip("\n").split("\n")
                    for line in lines:
                        print(f"[{self.command_prefix}] {line}")
                    print_buf = ""

            def handle_fd(fd: Optional[IO[Any]]) -> str:
                if fd and fd in r:
                    read = os.read(fd.fileno(), 4096)
                    if len(read) == 0:
                        rlist.remove(fd)
                    else:
                        return read.decode("utf-8")
                return ""

            stdout_buf += handle_fd(stdout)
            stderr_buf += handle_fd(stderr)
        return stdout_buf, stderr_buf

    def _run(
        self, cmd: str, shell: bool, stdout: FILE = None, stderr: FILE = None
    ) -> subprocess.CompletedProcess:
        with ExitStack() as stack:
            if stdout is None or stderr is None:
                read_fd, write_fd = stack.enter_context(pipe())

            if stdout is None:
                stdout_read = None
                stdout_write = write_fd
            elif stdout == subprocess.PIPE:
                stdout_read, stdout_write = stack.enter_context(pipe())

            if stderr is None:
                stderr_read = None
                stderr_write = write_fd
            elif stderr == subprocess.PIPE:
                stderr_read, stderr_write = stack.enter_context(pipe())

            with subprocess.Popen(
                cmd, text=True, shell=shell, stdout=stdout_write, stderr=stderr_write
            ) as p:
                write_fd.close()
                if stdout == subprocess.PIPE:
                    stdout_write.close()
                if stderr == subprocess.PIPE:
                    stderr_write.close()
                stdout, stderr = self._prefix_output(read_fd, stdout_read, stderr_read)
                ret = p.wait()
                return subprocess.CompletedProcess(
                    cmd, ret, stdout=stdout, stderr=stderr
                )

    def run_local(
        self, cmd: str, stdout: FILE = None, stderr: FILE = None
    ) -> subprocess.CompletedProcess:
        print(f"[{self.command_prefix}] {cmd}")
        return self._run(cmd, shell=True, stdout=stdout, stderr=stderr)

    def run(
        self, cmd: str, stdout: FILE = None, stderr: FILE = None
    ) -> subprocess.CompletedProcess:
        print(f"[{self.command_prefix}] {cmd}")
        ssh_opts = ["-A"] if self.forward_agent else []
        cmd = (
            ["ssh", f"{self.user}@{self.host}", "-p", str(self.port)]
            + ssh_opts
            + ["--", cmd]
        )
        return self._run(cmd, shell=False, stdout=stdout, stderr=stderr)


DeployResults = List[Tuple[DeployHost, int]]


class DeployGroup:
    def __init__(self, hosts: List[DeployHost]) -> None:
        self.hosts = hosts

    def _run_local(
        self,
        cmd: str,
        host: DeployHost,
        results: DeployResults,
        stdout: FILE = None,
        stderr: FILE = None,
    ) -> None:
        results.append((host, host.run_local(cmd, stdout=stdout, stderr=stderr)))

    def _run_remote(
        self,
        cmd: str,
        host: DeployHost,
        results: DeployResults,
        stdout: FILE = None,
        stderr: FILE = None,
    ) -> None:
        results.append((host, host.run(cmd, stdout=stdout, stderr=stderr)))

    def _run(
        self, cmd: str, local: bool = False, stdout: FILE = None, stderr: FILE = None
    ) -> DeployResults:
        results: DeployResults = []
        threads = []
        for host in self.hosts:
            fn = self._run_local if local else self._run_remote
            thread = Thread(
                target=fn,
                kwargs=dict(
                    results=results, cmd=cmd, host=host, stdout=stdout, stderr=stderr
                ),
            )
            thread.start()
            threads.append(thread)

        for thread in threads:
            thread.join()

        return results

    def run(self, cmd: str, stdout: FILE = None, stderr: FILE = None) -> DeployResults:
        return self._run(cmd, stdout=stdout, stderr=stderr)

    def run_local(
        self, cmd: str, stdout: FILE = None, stderr: FILE = None
    ) -> DeployResults:
        return self._run(cmd, local=True, stdout=stdout, stderr=stderr)

    def run_function(self, func: Callable) -> None:
        threads = []
        for host in self.hosts:
            thread = Thread(
                target=func,
                args=(host,),
            )
            threads.append(thread)

        for thread in threads:
            thread.start()

        for thread in threads:
            thread.join()
