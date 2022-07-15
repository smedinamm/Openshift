FROM ibmcom/ace
RUN mkdir bars
COPY CalculatorTest.bar /home/aceuser/bars
RUN ace_compile_bars.sh
