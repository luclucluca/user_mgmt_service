package com.example.jwt.core.exception;

import com.example.jwt.domain.module.ModuleNotFoundException;
import com.example.jwt.domain.module.ModuleServiceUnavailableException;
import java.time.LocalDate;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class CustomGlobalExceptionHandler {

  @ExceptionHandler(MethodArgumentNotValidException.class)
  @ResponseStatus(value = HttpStatus.BAD_REQUEST)
  public ResponseError handleMethodArgumentNotValid(MethodArgumentNotValidException ex) {
    return new ResponseError()
        .setTimeStamp(LocalDate.now())
        .setErrors(ex.getBindingResult().getFieldErrors().stream().collect(
            Collectors.toMap(error -> error.getField(), error -> error.getDefaultMessage())))
        .build();
  }

  @ExceptionHandler(NoSuchElementException.class)
  @ResponseStatus(value = HttpStatus.NOT_FOUND)
  public ResponseError handleNotFound(NoSuchElementException ex) {
    return new ResponseError()
        .setTimeStamp(LocalDate.now())
        .setErrors(Map.of("id", ex.getMessage()))
        .build();
  }

  @ExceptionHandler(ModuleNotFoundException.class)
  @ResponseStatus(value = HttpStatus.NOT_FOUND)
  public ResponseError handleModuleNotFound(ModuleNotFoundException ex) {
    return new ResponseError()
        .setTimeStamp(LocalDate.now())
        .setErrors(Map.of("moduleId", ex.getMessage()))
        .build();
  }

  @ExceptionHandler(ModuleServiceUnavailableException.class)
  @ResponseStatus(value = HttpStatus.SERVICE_UNAVAILABLE)
  public ResponseError handleModuleServiceUnavailable(ModuleServiceUnavailableException ex) {
    return new ResponseError()
        .setTimeStamp(LocalDate.now())
        .setErrors(Map.of("moduleService", ex.getMessage()))
        .build();
  }

}


