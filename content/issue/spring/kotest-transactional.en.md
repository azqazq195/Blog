---
title: Data Not Rolling Back When Using @DataJpaTest with Kotest
type: blog
date: 2024-11-27
tags:
  - kotlin
  - spring
  - kotest
summary: "Explains transaction rollback issues and solutions when using Kotest with @DataJpaTest"
---

## Issue

There was an issue where data wasn't rolling back when using @DataJpaTest with Kotest.</br>
Let's look at the test code below.

```kotlin
@DataJpaTest
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository
) : BehaviorSpec({
    Given("existsByEmail") {
        val user = UserFixture.createEntity()
        userRepository.save(user)
        //..
    }

    Given("findByEmail") {
        val user = UserFixture.createEntity()
        userRepository.save(user)
        //..
    }
})
```

When running each Given block separately, the tests worked fine.</br>
However, when running the entire UserRepositoryTest, the following error occurred:

<figure style="display: inline-block; width: 100%">
  <img src="/images/issue/spring/kotest-transactional/test-result.png" align="center" width="600"/>
  <figcaption>Test Result</figcaption>
</figure>

```plantext
could not execute statement
[Unique index or primary key violation:
"PUBLIC.CONSTRAINT_INDEX_2 ON PUBLIC.""USER""(EMAIL NULLS FIRST) VALUES ( /* 6 */ 'email' )";
SQL statement:
...
```

## Cause

Following BehaviorSpec's pattern, we wanted the transaction to roll back after each Given block.
However, contrary to our intention, the Entity saved in Given("existsByEmail") wasn't rolled back, causing an email Unique constraint violation in Given("findByEmail").

## Investigation

Let's examine why transactions aren't being applied in Kotest.

### RollBack in @DataJpaTest

When testing JpaRepository, we typically use @DataJpaTest.
This annotation rolls back data after tests because it includes @Transactional.
You can see this in the @DataJpaTest annotation below:

@DataJpaTest:

```kotlin
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@BootstrapWith(DataJpaTestContextBootstrapper.class)
@ExtendWith(SpringExtension.class)
@OverrideAutoConfiguration(enabled = false)
@TypeExcludeFilters(DataJpaTypeExcludeFilter.class)
@Transactional // <-- here
@AutoConfigureCache
@AutoConfigureDataJpa
@AutoConfigureTestDatabase
@AutoConfigureTestEntityManager
@ImportAutoConfiguration
public @interface DataJpaTest
```

### Why Do Tests with @Transactional Roll Back?

In the Spring test framework, TransactionalTestExecutionListener manages Transactional behavior. Looking at the code, we can see this Listener checks the rollback status with a default value of true.

> Reference: [Spring Framework Official](https://docs.spring.io/spring-framework/reference/testing/testcontext-framework/tx.html)

```java
public class TransactionalTestExecutionListener extends AbstractTestExecutionListener {
    // ..
    protected final boolean isDefaultRollback(TestContext testContext) throws Exception {
        Class<?> testClass = testContext.getTestClass();
        Rollback rollback = TestContextAnnotationUtils.findMergedAnnotation(testClass, Rollback.class);
        boolean rollbackPresent = (rollback != null);

        if (rollbackPresent) {
            boolean defaultRollback = rollback.value();
            if (logger.isDebugEnabled()) {
                logger.debug(String.format("Retrieved default @Rollback(%s) for test class [%s].",
                defaultRollback, testClass.getName()));
            }
            return defaultRollback;
        }

        // else
        return true;
    }
    // ..
}

@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
public @interface Rollback {
 /**
  * Whether the <em>test-managed transaction</em> should be rolled back
  * after the test method has completed.
  * <p>If {@code true}, the transaction will be rolled back; otherwise,
  * the transaction will be committed.
  * <p>Defaults to {@code true}.
  */
 boolean value() default true; // <--here
}
```

### Transactions in Kotest

#### Log Configuration

Let's activate logging to see transaction progress

> Spring Boot 3.1.2

```yml
# src/test/resources/application.yml
spring:
  jpa:
  show-sql: true
  properties:
    hibernate:
      format_sql: true

logging:
  level:
    org.springframework.orm.jpa: DEBUG
    org.springframework.transaction: DEBUG
```

#### JUnit

Let's verify if rollback occurs in JUnit Test.
Below is a simple user entity save test.

JUnit:

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryJUnitJpaTest @Autowired constructor(
    private val userRepository: UserRepository,
) {
    @Test
    fun test() {
        userRepository.save(UserFixture.createEntity("email"))
    }
}
```

Console:

```plantext
Creating new EntityManager for shared EntityManager invocation
Started UserRepositoryJUnitJpaTest in 2.577 seconds (process running for 5.58)
Creating new transaction with name [com.moseoh.danggeunclone.core.domain.repository.UserRepositoryJUnitJpaTest.test]: PROPAGATION_REQUIRED,ISOLATION_DEFAULT
Opened new EntityManager [SessionImpl(572980523<open>)] for JPA transaction
Exposing JPA transaction as JDBC [org.springframework.orm.jpa.vendor.HibernateJpaDialect$HibernateConnectionHandle@1a899fcd]
OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended
Found thread-bound EntityManager [SessionImpl(572980523<open>)] for JPA transaction
Participating in existing transaction
Hibernate:
    insert
    into
        user
        (created_at,email,modified_at,nickname,password,role)
    values
        (?,?,?,?,?,?)
Initiating transaction rollback
Rolling back JPA transaction on EntityManager [SessionImpl(572980523<open>)]
Closing JPA EntityManager [SessionImpl(572980523<open>)] after transaction
```

Database:

```mysql
mysql> select * from user;
Empty set (0.00 sec)
```

#### Kotest

JUnit worked as intended with rollback. How about Kotest?
Here's the same logic written in Kotest.

Kotest:

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository,
) : BehaviorSpec({
    Given("given") {
        userRepository.save(UserFixture.createEntity("email1"))
    }
})
```

Console:

```plantext
Creating new EntityManager for shared EntityManager invocation
Started UserRepositoryTest in 2.319 seconds (process running for 5.332)
Creating new transaction with name [org.springframework.data.jpa.repository.support.SimpleJpaRepository.save]: PROPAGATION_REQUIRED,ISOLATION_DEFAULT
Opened new EntityManager [SessionImpl(2141284786<open>)] for JPA transaction
Exposing JPA transaction as JDBC [org.springframework.orm.jpa.vendor.HibernateJpaDialect$HibernateConnectionHandle@3a387ca]
Hibernate:
    insert
    into
        user
        (created_at,email,modified_at,nickname,password,role)
    values
        (?,?,?,?,?,?)
Initiating transaction commit
Committing JPA transaction on EntityManager [SessionImpl(2141284786<open>)]
Closing JPA EntityManager [SessionImpl(2141284786<open>)] after transaction
Closing JPA EntityManagerFactory for persistence unit 'default'
```

Database:

```mysql
mysql> select * from user;
+----------------------------+----+----------------------------+--------+----------+----------+------+
| created_at                 | id | modified_at                | email  | nickname | password | role |
+----------------------------+----+----------------------------+--------+----------+----------+------+
| 2023-08-01 18:46:06.559065 | 45 | 2023-08-01 18:46:06.559065 | email1 | nickname | password | USER |
+----------------------------+----+----------------------------+--------+----------+----------+------+
1 row in set (0.00 sec)
```

Unlike JUnit, in the `Given` TestScope, it doesn't create a transaction but creates one in the Repository.

> Creating new transaction with name .. SimpleJpaRepository.save .. Opened new EntityManager ..

Then it immediately commits after `save()` and closes, as we can see.

> Committing JPA transaction on EntityManager
> Closing JPA EntityManager

Since it didn't roll back, we can see the user entity is stored in the DB.

> 1 row in set (0.00 sec)

### Why Doesn't the Repository's Transaction Roll Back?

In Spring Test Context, TransactionalTestExecutionListener manages transactions. The Repository is part of the Spring Context due to @DataJpaTest, so it's not a management target.

#### When using Repository, you might notice (or not) that transactions are applied when executing each method.

Where is it applied?

When developing, we implement the JpaRepository interface.
The actual implementation becomes `SimpleJpaRepository`.
This is explained in detail in the post below.

> Reference: https://brunch.co.kr/@anonymdevoo/40#comment

### Applying Transactions in Kotest

The issue of transactions not being applied with @DataJpaTest is already registered as an issue.
Kotest suggests configuring SpringExtension through extensions to solve this problem.

You can set LifeCycleMode through extensions.
SpringTestLifecycleMode has two options, Root and Test, which can be used as follows:

> Reference: https://github.com/kotest/kotest/issues/1643

```kotlin
**
 * Determines how the spring test context lifecycle is mapped to test cases.
 *
 * [SpringTestLifecycleMode.Root] will setup and teardown the test context before and after root tests only.
 * [SpringTestLifecycleMode.Test] will setup and teardown the test context only at leaf tests.
 *
 */

enum class SpringTestLifecycleMode {
    Root, Test
}
```

- Root Test: Top-level test, typically the starting point of the test hierarchy.
  - Set up when entering top-level tests and tear down when finished.
  - In BehaviorSpec, this corresponds to Given (Container Scope).
- Leaf Test: Lowest-level test, actual execution test for specific test cases or scenarios.
  - Set up when entering lowest-level tests and tear down when finished.
  - In BehaviorSpec, this corresponds to Then (Test Scope).

Below is the extensions configuration.
SpringExtension has SpringTestLifecycleMode.Test as default and can be used in three ways:

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository,
) : BehaviorSpec({
    // SpringTestLifecycleMode.Root
    extensions(SpringTestExtension(SpringTestLifecycleMode.Root))

    // SpringTestLifecycleMode.Test
    extensions(SpringTestExtension(SpringTestLifecycleMode.Test))
    extensions(SpringTestExtension())
    extensions(SpringExtension)
})
```

I applied SpringTestLifecycleMode.Root because I wanted initialization for each Root Test, like when using JUnit + @DataJpaTest. This way, each Given can be isolated.

### Result

Let's run the updated code.

Kotest:

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository,
) : BehaviorSpec({
    extensions(SpringTestExtension(SpringTestLifecycleMode.Root))

    Given("given") {
        userRepository.save(UserFixture.createEntity("email1"))
    }
})
```

Console:

```plaintext
Creating new EntityManager for shared EntityManager invocation
Started UserRepositoryJUnitJpaTest in 2.577 seconds (process running for 5.58)
Creating new transaction with name [com.moseoh.danggeunclone.core.domain.repository.UserRepositoryJUnitJpaTest.UserRepositoryTest.given_6b6ce7a7_c569_4cab_b172_dfbbb4b0d5bb]: PROPAGATION_REQUIRED,ISOLATION_DEFAULT
Opened new EntityManager [SessionImpl(572980523<open>)] for JPA transaction
Exposing JPA transaction as JDBC [org.springframework.orm.jpa.vendor.HibernateJpaDialect$HibernateConnectionHandle@1a899fcd]
OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended
Found thread-bound EntityManager [SessionImpl(572980523<open>)] for JPA transaction
Participating in existing transaction
Hibernate:
    insert
    into
        user
        (created_at,email,modified_at,nickname,password,role)
    values
        (?,?,?,?,?,?)
Initiating transaction rollback
Rolling back JPA transaction on EntityManager [SessionImpl(572980523<open>)]
Closing JPA EntityManager [SessionImpl(572980523<open>)] after transaction
```

This looks familiar. It's the same as the log when using JUnit + `@DataJpaTest`.
One difference is that this method name includes 'given'.
`UserRepositoryTest.given_6b6ce7a7_c569_4cab_b172_dfbbb4b0d5bb`

#### Project Level Extensions Setting

We've completed the example, but one thing remains.
We can't set extensions(SpringTestExtension(SpringTestLifecycleMode.Root)) for every test class.

Kotest supports Project Level Config. Let's configure it commonly for the project.

> Reference: https://kotest.io/docs/framework/project-config.html

```kotlin
// src/test/kotlin
class KotestConfig : AbstractProjectConfig() {
    override fun extensions() = listOf(SpringTestExtension(SpringTestLifecycleMode.Root))
}
```

Now we don't need to write extensions in the example above.

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository,
) : BehaviorSpec({
    // extensions(SpringTestExtension(SpringTestLifecycleMode.Root)) Loaded from KotestConfig

    Given("given") {
        userRepository.save(UserFixture.createEntity("email1"))
    }
})
```

## Summary

When using Kotest + @DataJpaTest, add the following configuration:

```kotlin
// src/test/kotlin
class KotestConfig : AbstractProjectConfig() {
    override fun extensions() = listOf(SpringTestExtension(SpringTestLifecycleMode.Root))
}
```
