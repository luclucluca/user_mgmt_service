package com.example.jwt.domain.module;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

/**
 * REST-Client fuer module_service. Timeout kommt vom RequestFactory, Retry/CircuitBreaker
 * von resilience4j (Konfiguration siehe application.properties, Instanzname "moduleService").
 * HttpClientErrorException (4xx) ist dort bewusst von Retry/CircuitBreaker ausgeschlossen -
 * ein "Modul nicht gefunden" ist kein transientes Problem und soll nicht wiederholt werden.
 */
@Component
public class ModuleClient {

  private final RestClient restClient;

  public ModuleClient(RestClient.Builder builder,
      @Value("${module-service.base-url}") String baseUrl,
      @Value("${module-service.timeout-millis}") int timeoutMillis) {
    SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
    requestFactory.setConnectTimeout(timeoutMillis);
    requestFactory.setReadTimeout(timeoutMillis);
    this.restClient = builder.baseUrl(baseUrl).requestFactory(requestFactory).build();
  }

  @CircuitBreaker(name = "moduleService", fallbackMethod = "isAvailableFallback")
  @Retry(name = "moduleService")
  public boolean isAvailable(UUID moduleId) {
    try {
      restClient.get().uri("/api/v1/modules/{id}", moduleId).retrieve().toBodilessEntity();
      return true;
    } catch (HttpClientErrorException.NotFound e) {
      return false;
    }
  }

  @SuppressWarnings("unused")
  private boolean isAvailableFallback(UUID moduleId, Exception ex) {
    throw new ModuleServiceUnavailableException("module_service ist nicht erreichbar", ex);
  }

  @CircuitBreaker(name = "moduleService", fallbackMethod = "assignFallback")
  @Retry(name = "moduleService")
  public void assign(UUID userId, UUID moduleId) {
    restClient.put().uri("/api/v1/users/{userId}/modules/{moduleId}", userId, moduleId)
        .retrieve().toBodilessEntity();
  }

  @SuppressWarnings("unused")
  private void assignFallback(UUID userId, UUID moduleId, Exception ex) {
    throw new ModuleServiceUnavailableException("module_service ist nicht erreichbar", ex);
  }

}
