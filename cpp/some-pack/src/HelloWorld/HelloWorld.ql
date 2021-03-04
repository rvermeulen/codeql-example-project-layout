/**
 * @kind problem
 * @precision high
 * @problem.severity error
 * @tags hello-world
 */

import cpp
import HelloWorld // Import support library from common

from StringLiteral s
where
  exists(s.getValue().regexpFind("([hH]ello)|([wW]orld)", _, _)) and
  not isAHelloWorld(s.getValue())
select s
